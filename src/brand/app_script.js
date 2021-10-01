/**
 * Import BigQuery Conversions in a format that Google Ads import uses.
 *
 * See the documentation for more information about the Google Ads import:
 * https://support.google.com/google-ads/answer/7014069?hl=en-GB
 *
 * Before running this code the BigQuery service must be enabled, see the docs:
 * https://developers.google.com/apps-script/guides/services/advanced
 *
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

////////////////////////////////////////////////////////////////////////////////
// SET THESE CONSTANTS TO THE APPROPRIATE VALUES
////////////////////////////////////////////////////////////////////////////////
// The GCP project ID that contains the conversion data
const GCP_PROJECT_ID = '';
// The BigQuery dataset containing the conversion data
const GCP_DATASET_ID = '';
// The name of the table in BigQuery containing the conversion data
const GCP_TABLE_NAME = '';
// The sheet name to output the results to.
const OUTPUT_SHEET_NAME = 'Sheet1';
// The range in the output sheet that contains the data.
const OUTPUT_SHEET_RANGE = 'A:D';
// This maps the conversion type in BigQuery to a conversion action in Google
// Ads. The key is the conversion type column in BigQuery, the value is the name
// of the conversion action
const CONVERSION_MAP = {
  'PURCHASE': 'Revenue',
  'ADD_TO_BASKET': 'Add to basket',
  'PRODUCT_DETAILS_VIEW': 'Landing page view'
};

// The full table name in BigQuery
const GCP_FULL_TABLE_NAME = `${GCP_DATASET_ID}.${GCP_TABLE_NAME}`;

/**
 * The main entry point to the script.
 *
 * Run this to import the conversions.
 */
function main(){
  Logger.log('Starting conversion import.');
  const rows = getBigQueryData();
  clearGoogleSheet(OUTPUT_SHEET_NAME, OUTPUT_SHEET_RANGE);
  addHeadersToGoogleSheet();
  parseDataAndOutput(rows);
  Logger.log('Done.');
}

/**
 * Get the conversion data from BigQuery.
 *
 * @return {!Array<?Object>}: an array of rows from Bigquery.
 */
function getBigQueryData() {
  Logger.log('- Getting rows from BiqQuery.');

  const query = `
    SELECT
      gclId,
      FORMAT_TIMESTAMP('%Y-%m-%d %H:%M:%S', conversionDateTime) AS conversionDateTime,
      conversionValue,
      conversionType,
    FROM
      ${GCP_FULL_TABLE_NAME}`;

  Logger.log(`- Running query: ${query}`);

  const request = {
    query,
    useLegacySql: false
  };

  let queryResults = BigQuery.Jobs.query(request, GCP_PROJECT_ID);
  const jobId = queryResults.jobReference.jobId;

  // Check on status of the Query Job.
  let sleepTimeMs = 500;
  while (!queryResults.jobComplete) {
    Utilities.sleep(sleepTimeMs);
    sleepTimeMs *= 2;
    queryResults = BigQuery.Jobs.getQueryResults(GCP_PROJECT_ID, jobId);
  }

  // Get all the rows of results.
  let rows = queryResults.rows;
  while (queryResults.pageToken) {
    queryResults = BigQuery.Jobs.getQueryResults(GCP_PROJECT_ID, jobId, {
      pageToken: queryResults.pageToken
    });
    rows = rows.concat(queryResults.rows);
  }

  Logger.log('- The rows have been retrieved from BQ');
  Logger.log(rows);
  return rows;
}

/**
 * Clears a range of a Google Sheet.
 * @param {string} sheetName: the name of the sheet.
 * @param {string} sheetRange: the range to clear.
 */
function clearGoogleSheet(sheetName, sheetRange) {
  Logger.log(`Clearing range: ${sheetName}!${sheetRange}`);
  const sheet = SpreadsheetApp.getActiveSpreadsheet()
    .getSheetByName(sheetName);
  sheet.getRange(sheetRange).clear();
}

/**
 * Add headers to the Google Sheet
 */
function addHeadersToGoogleSheet() {
  Logger.log('Adding headers to the sheet.');
  const headers = [
    'Google Click ID',
    'Conversion Name',
    'Conversion Time',
    'Conversion value',
  ];
  writeRowToGoogleSheet(headers, OUTPUT_SHEET_NAME);
}

/**
 * Append an array of data as a row to the sheet.
 * @param {!Array} row: the row of data to write.
 * @param {string} sheetName: the sheet to append the row to.
 */
function writeRowToGoogleSheet(row, sheetName) {
  const sheet = SpreadsheetApp.getActiveSpreadsheet()
      .getSheetByName(sheetName);
  sheet.appendRow(row);
}

/**
 * Parse the BigQuery rows and write them to a sheet.
 * @param {!Array<?Object>} rows: an array of rows from Bigquery.
 */
function parseDataAndOutput(rows) {
  Logger.log('Parsing the BigQuery rows and writing to sheet.');
  for (const row of rows) {
    let sheet_row = [
      row.f[0].v,                 // gclid
      CONVERSION_MAP[row.f[3].v], // conversion name
      row.f[1].v,                 // conversion datetime
      row.f[2].v                  // conversion value
    ];
    writeRowToGoogleSheet(sheet_row, OUTPUT_SHEET_NAME);
  }
}
