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
 * Step 1: Creates a view of yesterday's Google Analytics session data.
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
CREATE OR REPLACE VIEW `coop_analytics.GASessionsYesterday`
AS (
  SELECT *
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_*`
  WHERE _TABLE_SUFFIX NOT LIKE 'intraday%' AND _table_suffix = '20170801'
  -- AND PARSE_DATE('%Y%m%d', _table_suffix) = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
)

/*
 * Step 2a: Create a view containing the fullVisitorIDs of purchasers.
 *
 * In this stage we're identifying the conversions of products in the Coop campaigns. This is
 * achieved by using the product SKU and e-commerce tracking fields.
 *
 * This script is looking at purchases as the conversions, and using the product price * product
 * quantity for the SKUs in the coop campaign, as the conversion value.
 */
CREATE OR REPLACE VIEW `coop_analytics.ConversionsPurchases`
AS (
  SELECT
    'PURCHASE' AS conversionType,
    Camp.campaignId,
    Analytics.fullVisitorId,
    TIMESTAMP_SECONDS(Analytics.visitStartTime) AS conversionDateTime,
    SUM(Prod.productPrice * Prod.productQuantity) AS conversionValue,
  FROM
    `coop_analytics.GASessionsYesterday` AS Analytics,
    UNNEST(hits) AS Hits,
    UNNEST(Hits.product) AS Prod
  INNER JOIN (SELECT sku, campaignId, FROM `coop_analytics.CoopCampaigns`) AS Camp
    ON Camp.sku = Prod.productSKU
  WHERE
    -- Completed purchase e-commerce event, see the schema for more details:
    -- https://support.google.com/analytics/answer/3437719?hl=en
    Hits.eCommerceAction.action_type = '6'
  GROUP BY 1, 2, 3, 4
)

/*
 * Step 2b: Create a view containing the fullVisitorIDs of visitors who add products to their basket.
 *
 * In this stage we're identifying the conversions of products in the Coop campaigns. This is
 * achieved by using the product SKU and e-commerce tracking fields.
 *
 * This script is looking at add to basket conversions, and using the product price * product
 * quantity for the SKUs in the coop campaign, as the conversion value.
 */
CREATE OR REPLACE VIEW `coop_analytics.ConversionsAddToBasket`
AS (
  SELECT
    'ADD_TO_BASKET' AS conversionType,
    Camp.campaignId,
    Analytics.fullVisitorId,
    TIMESTAMP_SECONDS(Analytics.visitStartTime) AS conversionDateTime,
    SUM(Prod.productPrice * Prod.productQuantity) AS conversionValue,
  FROM
    `coop_analytics.GASessionsYesterday` AS Analytics,
    UNNEST(hits) AS Hits,
    UNNEST(Hits.product) AS Prod
  INNER JOIN (SELECT sku, campaignId, FROM `coop_analytics.CoopCampaigns`) AS Camp
    ON Camp.sku = Prod.productSKU
  WHERE
    -- Add to basked e-commerce event, see the schema for more details:
    -- https://support.google.com/analytics/answer/3437719?hl=en
    Hits.eCommerceAction.action_type = '3'
  GROUP BY 1, 2, 3, 4
)

/*
 * Step 2c: Create a view containing the fullVisitorIDs of visitors who view the product details page.
 *
 * In this stage we're identifying the conversions of products in the Coop campaigns. This is
 * achieved by using the product SKU and e-commerce tracking fields.
 *
 * This script is looking at views of the product details page as conversions, and using the product
 * price as the conversion value.
 */
CREATE OR REPLACE VIEW `coop_analytics.ConversionsProductDetailsView`
AS (
  SELECT
    'PRODUCT_DETAILS_VIEW' AS conversionType,
    Camp.campaignId,
    Analytics.fullVisitorId,
    TIMESTAMP_SECONDS(Analytics.visitStartTime) AS conversionDateTime,
    SUM(Prod.productPrice) AS conversionValue,
  FROM
    `coop_analytics.GASessionsYesterday` AS Analytics,
    UNNEST(hits) AS Hits,
    UNNEST(Hits.product) AS Prod
  INNER JOIN (SELECT sku, campaignId, FROM `coop_analytics.CoopCampaigns`) AS Camp
    ON Camp.sku = Prod.productSKU
  WHERE
    -- Product detail view e-commerce event, see the schema for more details:
    -- https://support.google.com/analytics/answer/3437719?hl=en
    Hits.eCommerceAction.action_type = '2'
  GROUP BY 1, 2, 3, 4
)

/*
 * Step 3: Create a view unioning all the conversion types together.
 */
CREATE OR REPLACE VIEW `coop_analytics.ConversionsAll`
AS (
  SELECT * FROM `coop_analytics.ConversionsPurchases`
  UNION ALL
  SELECT * FROM `coop_analytics.ConversionsAddToBasket`
  UNION ALL
  SELECT * FROM `coop_analytics.ConversionsProductDetailsView`
)

/*
 * Step 4: Find which conversions came from a Coop Campaign and write results to a table.
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
  `conversionValue` DECIMAL)
  PARTITION BY DATE(conversionDateTime);

-- Insert the results into the table
INSERT INTO `coop_analytics.BrandConversions`
SELECT DISTINCT
  Campaigns.brand,
  Campaigns.campaignId,
  CustomDimension.value AS gclId,
  Conversions.conversionType,
  Conversions.conversionDateTime,
  Conversions.conversionValue,
FROM
  `bigquery-public-data.google_analytics_sample.ga_sessions_*` AS Analytics,
  UNNEST(customDimensions) AS CustomDimension
INNER JOIN `coop_analytics.ConversionsAll` AS Conversions
  ON Analytics.fullVisitorId = Conversions.fullVisitorId
INNER JOIN
  (
    SELECT campaignId, utmSource, utmMedium, utmCampaign, ARRAY_AGG(sku) AS skus
    FROM `coop_analytics.CoopCampaigns`
    GROUP BY campaignId, utmSource, utmMedium, utmCampaign
  ) AS Campaigns
  ON
    Campaigns.campaignId = Conversions.campaignId
    AND Campaigns.utmSource = Analytics.trafficSource.source
    AND Campaigns.utmMedium = Analytics.trafficSource.medium
    AND Campaigns.utmCampaign = Analytics.trafficSource.campaign
WHERE
  -- Change this value to the index of the custom dimension containing the GCLID
  CustomDimension.index = 4
  AND CustomDimension.value IS NOT NULL
  AND Analytics._TABLE_SUFFIX NOT LIKE 'intraday%'
  AND (
    TIMESTAMP_SECONDS(Analytics.visitStartTime)
    >= TIMESTAMP_SUB(Conversions.conversionDateTime, INTERVAL 90 DAY));

/*
 * Step 5: Create views for each brand in their own datasets for sharing back with the brands.
 *
 * Prior to running this script datasets need to be created for each of the brands.
 * To use the automated version, make sure that the brand name and the dataset name match.
 *
 * See docs for more details:
 * https://cloud.google.com/bigquery/docs/share-access-views
 *
 * For manual version - required changes to use:
 *  - Update the brand names and datasets accordingly.
 */

-- Automated version
FOR
  brand IN (SELECT DISTINCT brand FROM `coop_analytics.BrandConversions`)
    DO
      EXECUTE
        IMMEDIATE
          FORMAT(
            '''
 CREATE OR REPLACE VIEW `%s.CoopAnalyticConversions` AS (
 SELECT * 
 FROM `coop_analytics.BrandConversions`
 WHERE brand = %s
 )
 ''',
            brand.brand,
            brand.brand);

END FOR;

-- Manual version
/*
CREATE OR REPLACE VIEW `global_brand_inc.CoopAnalyticConversions` AS (
  SELECT *
  FROM `coop_analytics.BrandConversions`
  WHERE brand = 'GlobalBrandInc'
);

CREATE OR REPLACE VIEW `best_brand.CoopAnalyticConversions` AS (
  SELECT *
  FROM `coop_analytics.BrandConversions`
  WHERE brand = 'BestBrand'
);
*/