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
 * Create a view unioning all the conversion types together.
 */
CREATE OR REPLACE VIEW `coop_analytics.ConversionsAll` AS (
  SELECT * FROM `coop_analytics.ConversionsPurchases`
  UNION ALL
  SELECT * FROM `coop_analytics.ConversionsAddToBasket`
  UNION ALL
  SELECT * FROM `coop_analytics.ConversionsProductDetailsView`
)
