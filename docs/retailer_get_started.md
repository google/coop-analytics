# Coop Analytics - Retailer Get Started

This guide explains how to get started with the code in this project as a
retailer.

The code in this project uses the
[Google Analytics sample dataset for BigQuery](https://support.google.com/analytics/answer/7586738?hl=en),
as a proof of concept (see [GA4 sample dataset](https://support.google.com/analytics/answer/10937659?hl=en&ref_topic=9359001#zippy=%2Cin-this-article) for the GA4 implementation). The script provided is an example and require modifying
to work with your data. The script has 5 separate steps, instructions for the
modifications required on each step are provided in the comments and below.

## Overview

1.  As the retailer, set up the
    [BigQuery export for Google Analytics 360](https://support.google.com/analytics/answer/3437618?hl=en) (or [GA4 BigQuery export](https://support.google.com/analytics/answer/9358801?hl=en&ref_topic=9359001))
    into a Google Cloud Project.

1.  Make a copy of this
    [spreadsheet](https://docs.google.com/spreadsheets/d/1Mq5VPuDpJ64t6yC5RH2yvw2QQzO0Bkc0R_x2zh0RQek/edit?usp=sharing&resourcekey=0-mmj4bfs_9YYa2Z1KcmpCmQ)
    and edit the configuration based on the agreement with the brand: clear all
    the sample data and replace this with the agreed SKUs, UTM parameters, a
    unique campaign name, and the name of the brand.

1.  In your Cloud project, open Cloud shell and run these commands to generate a
    table from the Google Sheet created above. Modify the first command by
    entering the Spreadsheet URL and the second command by entering dataset name
    and table name. By default, this and the following tables are created in the
    `coop_analytics` dataset but it can be a name of your choice. The table
    created by this command will be called `CoopCampaigns` by default. If you
    change the table name, please replace it in the `retailer_setup.sql` script
    too (with GA4, please use `retailer_setup_GA4.sql`).

    ```
    bq mkdef --autodetect --source_format=GOOGLE_SHEETS "INSERT_SPREADSHEET_URL" > /tmp/bq_create_table

    bq mk -table --schema=sku:STRING,campaignId:STRING,brand:STRING,utmSource:STRING,utmMedium:STRING,utmCampaign:STRING --external_table_definition=/tmp/bq_create_table coop_analytics.CoopCampaigns
    ```

1.  Modify the SQL script in this project (more details below).

1.  Schedule the script to run on a daily basis, see the scheduling section
    below for more details.

1.  Share the final data with the brand:

    -   The simplest solution is to create a separate BigQuery dataset that
        contains
        [a view of the brand's data](https://cloud.google.com/bigquery/docs/share-access-views),
        and share this with the brand. This project creates this data, but does
        not share the data with the brand.
    -   Alternatively,
        [the data can be exported from BigQuery to Cloud Storage](https://cloud.google.com/bigquery/docs/exporting-data)
        and that shared with the brand.
    -   Or there are other ETL alternatives that could be used, if there are
        other specific restrictions/requirements.

## SQL Script Steps

The script by default creates resources in a dataset called `coop_analytics`.
This dataset either needs to be created, or the script needs to be modified to
write to a dataset name of your choice.

Below outlines the modifications required to each step:

-   **Step 1 - Create analytics view**: creates a view of yesterday's Analytics
    export. Changes:

    -   The sample dataset
        `bigquery-public-data.google_analytics_sample.ga_sessions_*` needs to be
        replaced with your Analytics dataset. Note the `*` at the end of the
        table, this needs to be present at the end of yours, as it is replaced
        in the WHERE clause using yesterday's date. If you're setting this up with the GA4 export, replace `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`.
    -   The WHERE clause needs updating to remove the hardcoded date example,
        and replaced with the commented out text.

-   **Step 2a - Conversions purchasers**: creates a view of purchasers of the
    coop SKUs. No changes required.

-   **Step 2b - Conversions add to basket**: creates a view of add to basket
    conversions of the coop SKUs. No changes required.

-   **Step 2c - Conversions product details view**: creates a view of add to
    basket conversions of the coop SKUs. No changes required.

-   **Step 3 - Join conversions**: creates a view that combines all the
    conversion types into one consolidated view. Changes:

    -   Remove any conversions types that are not relevant.

-   **Step 4 - Find conversion gclids**: Creates a table containing a subset of
    the conversions which originated from the brands, containing only the GCLID,
    campaign ID & brand name (created in step 1), the type of conversion, the
    date time of the conversion, and the conversion value. Changes:

    -   This script uses any click attribution, if this is not correct this
        script needs to be tweaked.
    -   The FROM statement references the sample Analytics data
        `bigquery-public-data.google_analytics_sample.ga_sessions_*` (or `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*` for GA4). This needs
        to be replaced, again with the wildcard `*`.
    -   The 90 in the WHERE condition is the number of days in the lookback
        window: `TIMESTAMP_SUB(Conversions.conversionDateTime, INTERVAL 90 DAY)`
        Change this to the appropriate value.
    -   In the WHERE clause update `CustomDimension.index = 4` to the index of
        the custom dimension containing the GCLID. In the GA4 version, update the `EventParams.key` to the name of the Custom Dimension containing the GCLID.

-   **Step 5 - Create brand views**: creates brand specific views of the data,
    so a brand can only view data that is to be shared with them. Changes:

    -   Prior to running this script, the datasets need to created for each
        brand in BigQuery. An example from the code is:
        `global_brand_inc.CoopAnalyticConversions` where the `global_brand_inc`
        dataset needs to be created, with the intention of sharing this with
        Global Brand Inc. The idea is to share this view with the brand,
        [see docs](https://cloud.google.com/bigquery/docs/share-access-views).
        If you are uncomfortable using a VIEW, `CREATE OR REPLACE VIEW` can be
        swapped with `CREATE OR REPLACE TABLE` to create a copy of the data
        instead.


## Scheduling

[BigQuery supports scheduling queries](https://cloud.google.com/bigquery/docs/scheduling-queries).
This is the simplest solution to scheduling. However, the Analytics transfer has
no SLAs and is not guaranteed to run by a certain time. If this scheduling is
deployed, schedule the script towards the end of the day.

For more advanced scheduling,
[Pub/Sub](https://cloud.google.com/pubsub/docs/overview) could be deployed to
trigger a [cloud function](https://cloud.google.com/functions) to orchestrate
the SQL scripts.

## Useful Links

-   [The Analytics BigQuery Schema](https://support.google.com/analytics/answer/3437719?hl=en)
-   [The GA4 BigQuery Schema](https://support.google.com/analytics/answer/7029846?hl=en)
