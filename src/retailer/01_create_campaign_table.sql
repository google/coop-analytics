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
 * Creates a table containing the Coop Campaign data.
 *
 * Each row in this table represents one coop campaign, between a retailer and a brand. A row
 * requires a unique campaign ID, the name of the brand, a UTM source, medium and campaign and a
 * list of SKUs that are being promoted in the campaign.
 *
 * The data below is provided for example purposes only and is based on the Analytics sample dataset
 * for BigQuery, see docs/get_started.md. The unusual placeholder UTM parameters are to match the
 * data in the sample dataset, where the real values have been replaced with these values.
 *
 * Required changes to use:
 *  - Clear the sample data and replace this with details of your coop arrangement.
 */
CREATE OR REPLACE TABLE `coop_analytics.CoopCampaigns`
AS (
  SELECT
    'Campaign1' AS campaignId,
    'GlobalBrandInc' AS brand,
    '(direct)' AS utmSource,
    '(none)' AS utmMedium,
    '(not set)' AS utmCampaign,
    [
      'GGOEGCBQ016499',
      'GGOEGCBB074199',
      'GGOEGALB036516',
      'GGOEGALQ036616',
      'GGOEGATJ060516',
      'GGOEGPJC203399',
      'GGOEYOCR077799',
      'GGOEGAAX0351',
      'GGOEGAAX0356',
      'GGOEYFKQ020699',
      'GGOEYHPB072210',
      'GGOEYDHJ056099',
      'GGOEGAAX0318',
      'GGOEGAAX0104',
      'GGOEGAAX0661',
      'GGOEGAAX0325',
      'GGOEGAAX0290',
      'GGOEGAAX0330',
      'GGOEGAAX0296',
      'GGOEAXXX0808',
      'GGOEGBRA037499',
      'GGOEGBRJ037399',
      'GGOEGAAX0338',
      'GGOEGCBC074299',
      'GGOEAFKQ020599',
      'GGOEGAAX0352',
      'GGOEGAAX0357',
      'GGOEGFKA022299',
      'GGOEGAAX0353',
      'GGOEGAAX0334',
      'GGOEGAAX0320',
      'GGOEGAAX0324',
      'GGOEGAAX0329',
      'GGOEGBRJ037299',
      'GGOEGBRB013899',
      'GGOEGESQ016799',
      'GGOEAKDH019899',
      'GGOEGESB015099',
      'GGOEAFKQ020499',
      'GGOEGESC014099',
      'GGOEGFKQ020799',
      'GGOEGESB015199',
      'GGOEGHPJ080310',
      'GGOEGDHC074099',
      'GGOEGFKQ020399',
      'GGOEAOCB077499',
      'GGOEGCMB020932',
      'GGOEGBCR024399',
      'GGOEGBJL013999',
      'GGOEA0CH077599',
      'GGOEGBPB081999',
      'GGOEADHH073999',
      'GGOEGEVA022399',
      'GGOEGBPB082099',
      'GGOEGCBB074399',
      'GGOEACCQ017299'] AS skus
  UNION ALL
  SELECT
    'Campaign2',
    'BestBrand',
    '(direct)',
    '(none)',
    '(not set)',
    [
      'GGOEGCBQ016499',
      'GGOEGCBB074199',
      'GGOEGALB036516',
      'GGOEGALQ036616',
      'GGOEGATJ060516']
)
