# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

/*
 * Creates a view of yesterday's Google Analytics session data.
 *
 * This is an example that is based off of the Analytics sample dataset for for BigQuery, see
 * see docs/get_started.md. This data is not updated and is available from 1-Aug-2016 to 1-Aug-2017,
 * so yesterday's data contains no rows. As a result, the WHERE condition is filtering on a specific
 * static date.
 *
 * Required changes to use:
 *  - Update the FROM statement to read from your Analytics export.
 *  - Uncomment the WHERE condition to filter the VIEW to yesterday's data and remove the hard-coded
 *    _table_suffix filter.
 */
CREATE OR REPLACE VIEW `coop_analytics.GASessionsYesterday` AS (
  SELECT
    *
  FROM
    `bigquery-public-data.google_analytics_sample.ga_sessions_*`
  WHERE
    _TABLE_SUFFIX NOT LIKE 'intraday%'
    AND _table_suffix = '20170801'
    -- AND PARSE_DATE('%Y%m%d', _table_suffix) = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
)
