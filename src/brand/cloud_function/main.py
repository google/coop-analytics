"""Import Conversions from BigQuery to a Google Sheet using Cloud Functions.

See the documentation for more information about the Google Ads import:
https://support.google.com/google-ads/answer/7014069?hl=en-GB

Before running view the README.md for how to set up and deploy this code.

Copyright 2022 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

  https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
"""
import logging
import sys
from typing import Any, Dict, List

from flask import jsonify
import google.auth
from google.cloud import bigquery
from googleapiclient.discovery import build

# Create a BQ client object
BQ_CLIENT = bigquery.Client()

# The scopes for the Google Sheets API
SCOPES = ['https://www.googleapis.com/auth/spreadsheets']
# Create a Google Sheets service to the API using the service account creds.
CREDENTIALS, _ = google.auth.default(scopes=SCOPES)
GOOGLE_SHEET_SERVICE = build('sheets', 'v4', credentials=CREDENTIALS)

# Set logging variables
logging.basicConfig(stream=sys.stdout, level=logging.INFO)
logger = logging.getLogger(__name__)


def main(request):
  """The main entry point for the code.

  Run this to import the conversions.

  Args:
      request (flask.Request): HTTP request object.
      The payload should take the form:  {
        "gcp_project_id": "project123",
        "gcp_dataset_id": "coop_analytics",
        "gcp_table_name": "BrandConversions",
        "google_sheet_id": "abcdefg123",
        "google_sheet_range": "Sheet1!A:D",
        "conversion_map": {
            "PURCHASE": "Revenue",
            "ADD_TO_BASKET": "Add to basket",
            "PRODUCT_DETAILS_VIEW": "Landing page view", } }
      - gcp_project_id: the Cloud project containing the BQ dataset.
      - gcp_dataset_id: the BigQuery dataset containing the conversion data.
      - gcp_table_name: the name of the table in BigQuery containing the
        conversion data.
      - google_sheet_id: the Sheet ID of the Google Sheet to output the
        conversions to.
      - google_sheet_range: the range in the sheet to use.
      - conversion_map: this maps the conversion type in BigQuery to a
        conversion action in Google Ads. The key is the conversion type column
        in BigQuery, the value is the name of the conversion action.

  Returns:
      A JSON response confirming the status as COMPLETED.
  """
  logger.info('Starting conversion import.')

  logger.info('Checking payload is as expected.')
  payload = request.get_json(silent=True)
  request_keys = set(payload.keys())
  expected_keys = {
      'gcp_dataset_id', 'gcp_table_name', 'google_sheet_id',
      'google_sheet_range', 'conversion_map'
  }

  if not request_keys.issuperset(expected_keys):
    logger.error('Payload keys do not match the expected keys.')
    logger.error(request_keys)
    logger.error(expected_keys)
    return jsonify({
        'status': 'FAILED',
        'message': 'The payload keys do not match the expected keys.',
        'payload_keys': request_keys,
        'expected_keys': expected_keys,
    }), 400
  
  # If no project ID is specified, use current project ID
  project_id = payload.get('gcp_project_id', process.env.GCP_PROJECT)

  rows = get_bigquery_data(project_id,
                          payload['gcp_dataset_id'],
                          payload['gcp_table_name'])
  clear_google_sheet(payload['google_sheet_id'], payload['google_sheet_range'])
  add_headers_to_google_sheet(payload['google_sheet_id'],
                              payload['google_sheet_range'])
  parse_rows_and_output(rows, payload['google_sheet_id'],
                        payload['google_sheet_range'],
                        payload['conversion_map'])

  logger.info('Done.')
  return jsonify({'status': 'COMPLETED'})


def get_bigquery_data(gcp_project_id: str,
                      gcp_dataset_id: str,
                      gcp_table_name: str) -> bigquery.table.RowIterator:
  """Fetch the conversion data from BigQuery.

  Args:
    gcp_project_id: the Cloud project id containing the BigQuery dataset
    gcp_dataset_id: the BigQuery dataset containing the conversion data.
    gcp_table_name: the name of the table in BigQuery containing the conversion
      data.

  Returns:
    A BigQuery RowIterator object containing the conversion data.
    A row will have the following headers:
      - gclId
      - conversionDateTime
      - conversionValue
      - conversionType
  """
  logger.info('- Getting rows from BiqQuery.')
  full_table_name = f'{gcp_project_id}.{gcp_dataset_id}.{gcp_table_name}'
  query = f"""
    SELECT
      gclId,
      FORMAT_TIMESTAMP('%Y-%m-%dT%H:%M:%S%z', conversionDateTime) AS conversionDateTime,
      conversionValue,
      conversionType,
    FROM
      {full_table_name}
    WHERE
      DATE(conversionDateTime) >=  DATE_SUB(CURRENT_DATE(), INTERVAL 3 DAY)"""
  query_job = BQ_CLIENT.query(query)
  return query_job.result()


def clear_google_sheet(sheet_id: str, sheet_range: str) -> None:
  """Clears the range in the Google Sheet.

  Args:
    sheet_id: the ID of the Google Sheet.
    sheet_range: the range in the Google Sheet to clear.
  """
  logger.info(f'- Clearing range: {sheet_range}')
  request = GOOGLE_SHEET_SERVICE.spreadsheets().values().clear(
      spreadsheetId=sheet_id, range=sheet_range, body={})
  request.execute()


def write_to_google_sheet(data: List[List[Any]], sheet_id: str,
                          sheet_range: str) -> None:
  """Write the data to the Google Sheet.

  Args:
    data: a list of lists where each nested list is a row to write to the sheet.
    sheet_id: the ID of the Google Sheet.
    sheet_range: the range in the Google Sheet to write to.
  """
  logger.info('- Writing data to Google Sheet.')
  body = {
      'majorDimension': 'ROWS',
      'values': data,
  }
  request = GOOGLE_SHEET_SERVICE.spreadsheets().values().append(
      spreadsheetId=sheet_id,
      range=sheet_range,
      valueInputOption='RAW',
      insertDataOption='INSERT_ROWS',
      body=body)
  request.execute()


def add_headers_to_google_sheet(sheet_id: str, sheet_range: str) -> None:
  """Add headers to the Google Sheet.

  Args:
    sheet_id: the ID of the Google Sheet.
    sheet_range: the range in the Google Sheet to write to.
  """
  logger.info('- Adding headers to the sheet.')
  headers = [[
      'Google Click ID',
      'Conversion Name',
      'Conversion Time',
      'Conversion value',
  ]]
  write_to_google_sheet(headers, sheet_id, sheet_range)


def parse_rows_and_output(rows: bigquery.table.RowIterator, sheet_id: str,
                          sheet_range: str, conversion_map: Dict[str,
                                                                 str]) -> None:
  """Parse the BigQuery rows and write them to the Google Sheet.

  Args:
    rows: the rows returned from the BigQuery query.
    sheet_id: the ID of the Google Sheet.
    sheet_range: the range in the Google Sheet to write to.
    conversion_map: a dictionary containing the BigQuery conversion name as the
      key, and the conversion action in Google Ads as the value.
  """
  logger.info('- Parse rows and output.')
  output_data = []
  for row in rows:
    output_data.append([
        row.gclId,
        conversion_map[row.conversionType],
        row.conversionDateTime,
        float(row.conversionValue),
    ])
  logger.info(output_data)
  write_to_google_sheet(output_data, sheet_id, sheet_range)
