# Coop Analytics

A brand wants to run an ad campaign and direct traffic to a retailer's site. To
enable more advanced bidding strategies, the brand's ad account needs to receive
conversions. Usually this is achieved by adding a JavaScript tag to the website,
but in this setup, the brand doesn't own the website, and a retailer may not
wish to modify their website to send conversions to a 3rd party Ads account.

Coop Analytics facilitates coop agreements, by using data from the retailer's
Google Analytics 360 account, to identify brand conversions and share these back
with the brand for conversion reporting.

## How It Works?

First, a brand and retailer come to an agreement for which products will be
promoted, and share the product SKUs, and agree a set of [UTM parameters](
https://en.wikipedia.org/wiki/UTM_parameters).

As an example, let's say that Global Brand Inc. would like to promote a pair of
socks on Retailer ABC's website. This would be the data flow:

1. Global Brand Inc. would like to promote these socks on the Retailer ABC's
   website:

   https://retailer-abc.com/products/global-brand-inc-socks.html

1. Global Brand Inc. set up a campaign in their own Ads account, with the agreed
   UTM parameters:

   https://retailer-abc.com/products/global-brand-inc-socks.html?utm_source=gbi_brand&utm_campaign=123

1. Global Brand Inc. enables [Auto-tagging](
   https://support.google.com/google-ads/answer/3095550) in their Google Ads
   account, so when a user clicks the link, a [GCLID](
   https://support.google.com/google-ads/answer/9744275?hl=en-GB) is also
   appended to the URL.

   https://retailer-abc.com/products/global-brand-inc-socks.html?utm_source=gbi_brand&utm_campaign=123&gclid=987zyx

1. Google Analytics on Retailer ABC's website will capture the GCLID and UTM
   parameters. See the [prerequisites](#Prerequisites) to ensure this
   behaves this way.

1. Retailer ABC sets up the [Google Analytics 360 BigQuery export](
   https://support.google.com/analytics/answer/3437618?hl=en) in their own
   Google Cloud Project. Global Brand Inc. will not have access to this.

1. Retailer ABC runs the SQL scripts in this project to find conversions for
   products that Global Brand Inc. are advertising. These scripts then look back
   30/60/90 days and determine if a click ever came from one of the brand's
   campaigns, by using the UTM parameters. Notes:

   - The look back window can be configured to any time period.
   - The attribution method in this code is any click, however this could be
     adapted to use first click or last click attribution, if desired.
   - There is flexibility as to what a conversion actually is. This code
     provides examples using page detail view, adding a product to basket, and
     making a purchase.

1. Once the converted clicks that originated from Global Brand Inc.'s campaign
   have been identified, the date & time of the conversion, the conversion value
   and the GCLID are stored in a table.

   |GCLID  |Conversion Datetime|Conversion Value|
   |-------|-------------------|----------------|
   |abc-123|01/02/2021 12:58   |11.99           |
   |xyz-854|01/02/2021 16:12   |23.98           |
   |dkd-954|02/02/2021 09:43   |11.99           |

1. This conversion table sits within Retailer ABC's cloud project. This table is
   shared with Global Brand Inc. Notes:

   - How the data is shared can be flexible:
     - The simplest solution is to create a separate BigQuery dataset that
       contains [a view of the brand's data](
       https://cloud.google.com/bigquery/docs/share-access-views), and share this
       with the brand. This project creates this data, but does not share the data
       with the brand.
     - Alternatively, [the data can be exported from BigQuery to Cloud Storage](
       https://cloud.google.com/bigquery/docs/exporting-data) and that shared with
       the brand.
     - Or there are other ETL alternatives that could be used, if there are other
       specific restrictions/requirements.
   - **Key point**: The brand's Ads account generated the GCLIDs. A brand can
     [report on the GCLIDs](
     https://developers.google.com/adwords/api/docs/appendix/reports/click-performance-report)
     even if no data is shared. The retailer is sharing a subset of the GCLIDs
     back with the brand; the ones that converted.

1. Global Brand Inc. reads the data, and reports this back to Google Ads via the
   [Offline Conversion API](
   https://developers.google.com/google-ads/api/docs/samples/upload-offline-conversion)


## Prerequisites

- The brand will pay 100% of the costs.
- The retailer must:
  - Be a [Google Analytics 360](
    https://marketingplatform.google.com/about/analytics-360/) customer ([the
    BigQuery export](https://support.google.com/analytics/answer/3437618?hl=en)
    is only available to Analytics 360 customers.)
  - Have [Enhanced Ecommerce actions set up](https://developers.google.com/tag-manager/enhanced-ecommerce).
    This code uses the actions to identify conversions.
  - Have a Google Cloud Project with access to [BigQuery](
    https://cloud.google.com/bigquery).
  - Set up a custom dimension at "session" level scope, that captures the GCLID
    and stores it as a custom dimension, see below for more details.


### GCLID Custom Dimension

Google Analytics validates the GCLID values that are appended to a query
string, and "invalid" GCLIDs are ignored, not stored in Google Analytics and
therefore don't make it to the BigQuery export.

The GCLID is encrypted data that contains information about the
Google Ads campaign it originated from.

The below example is clearly not going to be a valid value:

https://retailer-abc.com/products/global-brand-inc-socks.html?gclid=987zyx

So this is ignored.

However, it's more complicated in our scenario, as a real GCLID will be
appended to the URL, but it will be from a different business's account; the
GCLID comes from the brand's Ads account, but the Analytics account belongs
to the retailer. As the GCLID comes from a foreign account, this is
considered invalid by Google Analytics.

This problem can be solved in two ways:

1. [Link the brand's Ads account with the retailer's Analytics account](https://support.google.com/analytics/answer/1033961?hl=en#zippy=%2Cin-this-article).
   Or,
2. Store the GCLID as a [custom dimension](https://support.google.com/analytics/answer/2709828?hl=en#zippy=%2Cin-this-article)
   with "session" level scope.

Option 1 solves the problem, as Google Analytics will now treat the GCLID as
coming from a valid account. However, many brands/retailers will be
uncomfortable with this account linking. As a result, this project uses
solution 2 above, so the accounts are not linked and there is still
separation between the businesses' Ads/Analytics accounts.

## Get Started
For information on how to get started, retailers visit [the retailer get
started guide](
docs/retailer_get_started.md).

For brands visit [the brand get started guide](docs/brand_get_started.md).


## Disclaimers
__This is not an officially supported Google product.__

Copyright 2021 Google LLC. This solution, including any related sample code or
data, is made available on an “as is,” “as available,” and “with all faults”
basis, solely for illustrative purposes, and without warranty or representation
of any kind. This solution is experimental, unsupported and provided solely for
your convenience. Your use of it is subject to your agreements with Google, as
applicable, and may constitute a beta feature as defined under those agreements.
To the extent that you make any data available to Google in connection with your
use of the solution, you represent and warrant that you have all necessary and
appropriate rights, consents and permissions to permit Google to use and process
that data. By using any portion of this solution, you acknowledge, assume and
accept all risks, known and unknown, associated with its usage, including with
respect to your deployment of any portion of this solution in your systems, or
usage in connection with your business, if at all.
