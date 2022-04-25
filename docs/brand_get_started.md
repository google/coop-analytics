# Coop Analytics - Brand Get Started

Once the retailer has shared the conversions table with the brand, there are
multiple ways to upload these conversions into Google Ads (or the other GMP
products).

For convenience, the brand might want to separate the table based on the
campaign they are associated to. To do this, run this query in your Big Query
environment.

```
FOR campaign IN
(
    SELECT DISTINCT campaignId
    -- This should be the table that was shared by the retailer
    FROM `project_id.coop_analytics.CoopAnalyticConversions`
)
DO EXECUTE IMMEDIATE FORMAT(
    """
    CREATE OR REPLACE TABLE dataset_name.coop_conversions_%s AS
    SELECT * WHERE campaign = %s
    """, campaign.campaignId, campaign.campaignId);
END FOR;
```

The options available have different levels of technical effort required for the
implementation:

1.  [Google Sheet Import](#Google-Sheet-Import): Upload conversions to Google
    Ads using a Google Sheet. See details below.
2.  [Megalista](https://github.com/google/megalista): Solution to upload
    conversions to Google Ads and Campaign Manager. Prerequisites:
    [Developer token](https://developers.google.com/google-ads/api/docs/first-call/dev-token)
    needed if using the Google Ads connector.
3.  Using the APIs directly: a brand can report conversions to Google Ads via
    the
    [Offline Conversion API](https://developers.google.com/google-ads/api/docs/samples/upload-offline-conversion).

## Google Sheet Import

For a lower barrier to entry, the brand could use:
[Google Ads conversion import from Google Sheets](https://support.google.com/google-ads/answer/7014069?hl=en-GB).

There are two methods for extracting the data into Google Sheets:

1.  Using App Script code.
2.  Using Cloud Functions.

Read below for more details of how to set this up.

### App Script

To set up the conversion import from Google Sheets the following needs to be
done:

1.  Create a new Google Sheet.

1.  Go to extensions -> app script.

1.  Copy the content of [app_script.js](../src/brand/app_script/code.js) into
    the code editor, replacing any code that exists.

1.  Click on the `+` next to services in the left hand panel and add the
    BigQuery API.

1.  At the top of the code are a number of variables that need to be updated,
    for example, the Cloud project ID, the name of the table containing the
    conversions etc.

1.  To run the code once, run the `main()` function. This should output all the
    conversions to the Google Sheet.

1.  To schedule the script to run daily:

    1.  Select triggers from the left hand menu.

    1.  Add trigger.

    1.  Make sure the following options are selected:

        -   Choose which function to run: main

        -   Which runs as deployment: head

        -   Select event source: Time-driven

        -   Select type of time based trigger: Day timer

        -   Select time of day: Midnight to 1am (or another time if you prefer)

1.  In the Google Ads UI configure the conversions to be imported from the
    Google Sheet
    [by following these instructions](https://support.google.com/google-ads/answer/7014069?hl=en-GB).

### Cloud Functions

1.  Create a new Google Sheet: [sheets.new](http://sheets.new) and make a note
    of the sheet ID from the URL, we need this later:

    ```
    https://docs.google.com/spreadsheets/d/[THIS IS THE SHEET ID]/edit
    ```

1.  Go to the Google Cloud Project and open Cloud Shell:

    ![Cloud Shell Button](images/cloud_shell.png)

1.  Clone this code base to the machine and navigate into the brand directory:

    ```
    git clone https://github.com/google/coop-analytics.git
    cd coop-analytics/src/brand/cloud_function
    ```

1.  Run the following commands to enable the APIs:

    ```
    gcloud services enable drive.googleapis.com
    gcloud services enable sheets.googleapis.com
    gcloud services enable cloudscheduler.googleapis.com
    ```

1.  Create a service account that is going to be used to run the code, and give
    it access to BigQuery, Cloud Scheduler & Cloud Functions:

    ```
    export GCP_CA_SERVICE_ACCOUNT=coop-analytics-sa
    export GCP_PROJECT_ID=$(gcloud config get-value project)

    gcloud iam service-accounts create $GCP_CA_SERVICE_ACCOUNT \
      --description="Coop Analytics Service Account" \
      --display-name="$GCP_CA_SERVICE_ACCOUNT"

    gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
     --member="serviceAccount:$GCP_CA_SERVICE_ACCOUNT@$GCP_PROJECT_ID.iam.gserviceaccount.com" \
     --role="roles/bigquery.dataViewer"

    gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
     --member="serviceAccount:$GCP_CA_SERVICE_ACCOUNT@$GCP_PROJECT_ID.iam.gserviceaccount.com" \
     --role="roles/bigquery.jobUser"

    gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
     --member="serviceAccount:$GCP_CA_SERVICE_ACCOUNT@$GCP_PROJECT_ID.iam.gserviceaccount.com" \
     --role="roles/cloudscheduler.serviceAgent"

    gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
     --member="serviceAccount:$GCP_CA_SERVICE_ACCOUNT@$GCP_PROJECT_ID.iam.gserviceaccount.com" \
     --role="roles/cloudfunctions.invoker"
    ```

1.  Share edit access to the Google Sheet with the service account. Run this
    command to see the email address:

    ```
    export GCP_CA_SERVICE_ACCOUNT_EMAIL=$GCP_CA_SERVICE_ACCOUNT@$GCP_PROJECT_ID.iam.gserviceaccount.com
    echo $GCP_CA_SERVICE_ACCOUNT_EMAIL
    ```

1.  Deploy the Cloud function:

    ```
    gcloud functions deploy coop-analytics-bigquery-to-sheets \
      --quiet \
      --runtime=python39 \
      --entry-point=main \
      --service-account=$GCP_CA_SERVICE_ACCOUNT_EMAIL \
      --trigger-http \
      --region=europe-west2 \
      --timeout=540s
    ```

1.  Set up cloud scheduler to run the job daily. Update the cron schedule to the
    appropriate value ([this tool can be helpful](https://crontab.guru/)), and
    update your Google Sheet ID in the message body:

    ```
    export GCP_CF_ENDPOINT=$(gcloud functions describe coop-analytics-bigquery-to-sheets --region=europe-west2 | grep -oP "url:\s\K[^,]+")

    gcloud scheduler jobs create http Coop-Analytics-Daily \
      --schedule="0 18 * * *" \
      --uri=$GCP_CF_ENDPOINT \
      --headers Content-Type=application/json --oidc-service-account-email=$GCP_CA_SERVICE_ACCOUNT_EMAIL \
      --http-method=post \
      --time-zone="Europe/London" \
      --message-body='{
                "gcp_dataset_id": "coop_analytics",
                "gcp_table_name": "BrandConversions",
                "google_sheet_id": "[YOUR SHEET ID]",
                "google_sheet_range": "Sheet1!A:D",
                "conversion_map": {
                    "PURCHASE": "Revenue",
                    "ADD_TO_BASKET": "Add to basket",
                    "PRODUCT_DETAILS_VIEW": "Landing page view"
                }
          }'
    ```

1.  In the Google Ads UI configure the conversions to be imported from the
    Google Sheet
    [by following these instructions](https://support.google.com/google-ads/answer/7014069?hl=en-GB).
