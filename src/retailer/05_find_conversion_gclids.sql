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
 * Find which conversions came from a Coop Campaign and write results to a table.
 *
 * The ConversionsAll table shows all the possible conversions, but now we need to identify which of
 * those originated from a coop campaign. To do this, we look back X days from the conversion date
 * and find any clicks that originated from the configured UTM parameters.
 *
 * The results are then output to a date partitioned table.
 *
 * It should be noted that in this example, we are using any click in the past 90 days as the
 * attribution style. This script could be modified for last click or first click, if that is
 * desired.
 *
 * Required changes to use:
 *  - Update the FROM statement to read from your Analytics export.
 *  - Change the 90 in the WHERE statement to the desired lookback window.
 *  - Update the CustomDimension.index to the index of the Custom Dimension containing the GCLID.
 */

-- Create the data partitioned table if it doesn't exist.
CREATE TABLE IF NOT EXISTS `coop_analytics.BrandConversions`(
  `brand` STRING,
  `campaignId` STRING,
  `gclId` STRING,
  `conversionType` STRING,
  `conversionDateTime` TIMESTAMP,
  `conversionValue` DECIMAL
)
PARTITION BY
  DATE(conversionDateTime);

-- Insert the results into the table
INSERT INTO `coop_analytics.BrandConversions`
SELECT DISTINCT
  Campaigns.brand,
  Campaigns.campaignId,
  CustomDimension.value as gclId,
  Conversions.conversionType,
  Conversions.conversionDateTime,
  Conversions.conversionValue,
FROM
  `bigquery-public-data.google_analytics_sample.ga_sessions_*` AS Analytics,
  UNNEST(customDimensions) as CustomDimension
INNER JOIN
  `coop_analytics.ConversionsAll` AS Conversions
  ON Analytics.fullVisitorId = Conversions.fullVisitorId
INNER JOIN
  `coop_analytics.CoopCampaigns` AS Campaigns
  ON Campaigns.campaignId = Conversions.campaignId
    AND Campaigns.utmSource = Analytics.trafficSource.source
    AND Campaigns.utmMedium = Analytics.trafficSource.medium
    AND Campaigns.utmCampaign = Analytics.trafficSource.campaign
WHERE
  -- Change this value to the index of the custom dimension containing the GCLID
  CustomDimension.index = 4
  AND CustomDimension.value IS NOT NULL
  AND Analytics._TABLE_SUFFIX NOT LIKE 'intraday%'
  AND (
    TIMESTAMP_SECONDS(Analytics.visitStartTime) >= TIMESTAMP_SUB(
      Conversions.conversionDateTime, INTERVAL 90 DAY)
  );
