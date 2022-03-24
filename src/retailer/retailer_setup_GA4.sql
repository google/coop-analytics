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
* Step 1: Creates a view of yesterday's GA4 event data.
*
* This is an example that is based off of the GA4 sample dataset for for BigQuery, see
* see docs/get_started.md. This data is not updated and is available from 1-Nov-2020 to 31-Jan-2021,
* so yesterday's data contains no rows. As a result, the WHERE condition is filtering on a specific
* static date.
*
* Required changes to use:
*  - Update the FROM statement to read from your GA4 export.
*  - Uncomment the WHERE condition to filter the VIEW to yesterday's data and remove the hard-coded
*    _table_suffix filter.
*/
CREATE OR REPLACE VIEW `coop_analytics.GA4EventsYesterday`
AS (
  SELECT *
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _table_suffix NOT LIKE 'intraday%' AND _table_suffix = '20210131'
  -- AND PARSE_DATE('%Y%m%d', _table_suffix) = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
);

/*
* Step 2a: Create a view containing the user_id of purchasers.
*
* In this stage we're identifying the conversions of products in the Coop campaigns. This is
* achieved by using the product SKU and e-commerce tracking fields.
*
* This script is looking at purchases as the conversions, and using the product price * product
* quantity for the SKUs in the coop campaign as the conversion value.
*/
CREATE OR REPLACE VIEW `coop_analytics.ConversionsPurchases`
AS (
  SELECT
    'PURCHASE' AS conversionType,
    Camp.campaignId,
    Analytics.user_id,
    TIMESTAMP_SECONDS(Analytics.event_timestamp) AS conversionDateTime,
    SUM(Prod.price * Prod.quantity) AS conversionValue,
  FROM `coop_analytics.GA4EventsYesterday` AS Analytics, UNNEST(Items) AS Prod
  INNER JOIN (SELECT sku, campaignId, FROM `coop_analytics.CoopCampaigns`) AS Camp
    ON Camp.sku = Prod.item_id
  WHERE
    -- Find standard GA4 event names at:
    -- https://developers.google.com/analytics/devguides/collection/ga4/ecommerce
    event_name = 'purchase'
  GROUP BY 1, 2, 3, 4
);

/*
 * Step 2b: Create a view containing the user_id of visitors who add products to their basket.
 *
 * In this stage we're identifying the conversions of products in the Coop campaigns. This is
 * achieved by using the product SKU and e-commerce tracking fields.
 *
 * This script is looking at add to basket conversions, and using the product price * product
 * quantity for the SKUs in the coop campaign as the conversion value.
 */
CREATE OR REPLACE VIEW `coop_analytics.GA4ConversionsAddToBasket`
AS (
  SELECT
    'ADD_TO_BASKET' AS conversionType,
    Camp.campaignId,
    Analytics.user_id,
    TIMESTAMP_SECONDS(Analytics.event_timestamp) AS conversionDateTime,
    SUM(Prod.price * Prod.quantity) AS conversionValue,
  FROM `coop_analytics.GA4EventsYesterday` AS Analytics, UNNEST(Items) AS Prod
  INNER JOIN (SELECT sku, campaignId, FROM `coop_analytics.CoopCampaigns`) AS Camp
    ON Camp.sku = Prod.item_id
  WHERE
    -- Find standard GA4 event names at:
    -- https://developers.google.com/analytics/devguides/collection/ga4/ecommerce
    event_name = 'add_to_cart'
  GROUP BY 1, 2, 3, 4
);

/*
 * Step 2c: Create a view containing the user_id of visitors who view the product details page.
 *
 * In this stage we're identifying the conversions of products in the Coop campaigns. This is
 * achieved by using the product SKU and e-commerce tracking fields.
 *
 * This script is looking at views of the product details page as conversions, and using the product
 * price as the conversion value.
 */

CREATE OR REPLACE VIEW `coop_analytics.GA4ConversionsProductDetailsView`
AS (
  SELECT
    'PRODUCT_DETAILS_VIEW' AS conversionType,
    Camp.campaignId,
    Analytics.user_id,
    TIMESTAMP_SECONDS(Analytics.event_timestamp) AS conversionDateTime,
    SUM(Prod.price) AS conversionValue,
  FROM `coop_analytics.GA4EventsYesterday` AS Analytics, UNNEST(Items) AS Prod
  INNER JOIN (SELECT sku, campaignId, FROM `coop_analytics.CoopCampaigns`) AS Camp
    ON Camp.sku = Prod.item_id
  WHERE
    -- Find standard GA4 event names at:
    -- https://developers.google.com/analytics/devguides/collection/ga4/ecommerce
    Analytics.event_name = 'view_item'
  GROUP BY 1, 2, 3, 4
);

/*
 * Step 3: Create a view unioning all the conversion types together.
 */

CREATE OR REPLACE VIEW `coop_analytics.GA4ConversionsAll`
AS (
  SELECT * FROM `coop_analytics.GA4ConversionsPurchases`
  UNION ALL
  SELECT * FROM `coop_analytics.GA4ConversionsAddToBasket`
  UNION ALL
  SELECT * FROM `coop_analytics.GA4ConversionsProductDetailsView`
);

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
 *  - Update the EventParams.key to the name of the Custom Dimension containing the GCLID.
 */

-- Create the data partitioned table if it doesn't exist.
INSERT INTO `coop_analytics.GA4BrandConversions`
SELECT DISTINCT
  Campaigns.brand,
  Campaigns.campaignId,
  EventParams.value.string_value AS gclId,
  Conversions.conversionType,
  Conversions.conversionDateTime,
  Conversions.conversionValue,
FROM
  `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*` AS Analytics,
  UNNEST(event_params) AS EventParams
INNER JOIN `coop_analytics.GA4ConversionsAll` AS Conversions
  ON Analytics.user_id = Conversions.user_id
INNER JOIN
  (
    SELECT campaignId, brand, utmSource, utmMedium, utmCampaign, ARRAY_AGG(sku) AS skus
    FROM `coop_analytics.CoopCampaigns`
    GROUP BY campaignId, brand, utmSource, utmMedium, utmCampaign
  ) AS Campaigns
  ON
    Campaigns.campaignId = Conversions.campaignId
    AND Campaigns.utmSource = Analytics.traffic_source.source
    AND Campaigns.utmMedium = Analytics.traffic_source.medium
    AND Campaigns.utmCampaign = Analytics.traffic_source.name
WHERE
  -- Change this value to the index of the custom dimension containing the GCLID
  EventParams.key = 'gclid'
  AND EventParams.value IS NOT NULL
  AND Analytics._TABLE_SUFFIX NOT LIKE 'intraday%'
  AND (
    TIMESTAMP_SECONDS(Analytics.event_timestamp)
    >= TIMESTAMP_SUB(
      Conversions.conversionDateTime,
      INTERVAL
        90
          DAY));

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
  brand IN (SELECT DISTINCT brand FROM `coop_analytics.GA4BrandConversions`)
    DO
      EXECUTE
        IMMEDIATE
          FORMAT(
            '''
 CREATE OR REPLACE VIEW `%s.CoopAnalyticConversions` AS (
 SELECT *
 FROM `coop_analytics.GA4BrandConversions`
 WHERE brand = "%s"
 )
 ''',
            brand.brand,
            brand.brand);

END FOR;

-- Manual version
/*
CREATE OR REPLACE VIEW `global_brand_inc.CoopAnalyticConversions` AS (
SELECT *
FROM `coop_analytics.GA4BrandConversions`
WHERE brand = 'GlobalBrandInc'
);
CREATE OR REPLACE VIEW `best_brand.CoopAnalyticConversions` AS (
SELECT *
FROM `coop_analytics.GA4BrandConversions`
WHERE brand = 'BestBrand'
);
*/