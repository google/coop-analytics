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
 * Create a view containing the fullVisitorIDs of visitors who view the product details page.
 *
 * In this stage we're identifying the conversions of products in the Coop campaigns. This is
 * achieved by using the product SKU and e-commerce tracking fields.
 *
 * This script is looking at views of the product details page as conversions, and using the product
 * price as the conversion value.
 */
CREATE OR REPLACE VIEW `coop_analytics.ConversionsProductDetailsView` AS (
  SELECT
    'PRODUCT_DETAILS_VIEW' AS conversionType,
    Camp.campaignId,
    Analytics.fullVisitorId,
    TIMESTAMP_SECONDS(Analytics.visitStartTime) AS conversionDateTime,
    SUM(Prod.productPrice) AS conversionValue,
  FROM
    `coop_analytics.GASessionsYesterday` AS Analytics,
    UNNEST(hits) AS Hits,
    UNNEST(Hits.product) as Prod
  INNER JOIN
    (
      SELECT
        sku,
        campaignId,
      FROM
        `coop_analytics.CoopCampaigns` AS Camp,
        UNNEST(Camp.skus) AS sku
    ) AS Camp
    ON Camp.Sku = Prod.productSKU
  WHERE
    -- Product detail view e-commerce event, see the schema for more details:
    -- https://support.google.com/analytics/answer/3437719?hl=en
    Hits.eCommerceAction.action_type = '2'
  GROUP BY
    1,2,3,4
)
