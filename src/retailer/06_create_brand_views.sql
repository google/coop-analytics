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
 * Create views for each brand in their own datasets for sharing back with the brands.
 *
 * Prior to running this script datasets need to be created for each of the brands.
 *
 * See docs for more details:
 * https://cloud.google.com/bigquery/docs/share-access-views
 *
 * Required changes to use:
 *  - Update the brand names and datasets accordingly.
 */
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
