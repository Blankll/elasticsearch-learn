#!/bin/bash

# Prompt for user input
read -p "Enter Elasticsearch host (format: [http|https]://host:port): " ES_HOST
read -p "Enter index name: " INDEX
read -p "Enter username (optional): " USERNAME
read -s -p "Enter password (optional): " PASSWORD
echo

MAPPING_FILE="$(dirname $0)/mapping.json"
CSV_FILE="$(dirname $0)/all_stocks_5yr.csv"

# Check files exist
if [[ ! -f "$MAPPING_FILE" ]]; then
  echo "Mapping file $MAPPING_FILE not found!"
  exit 1
fi
if [[ ! -f "$CSV_FILE" ]]; then
  echo "CSV file $CSV_FILE not found!"
  exit 1
fi

# Prepare auth if provided
AUTH=""
if [[ -n "$USERNAME" && -n "$PASSWORD" ]]; then
  AUTH="-u $USERNAME:$PASSWORD"
fi

# Create index with mapping

echo "Creating index $INDEX..."
CREATE_RESP=$(curl -s --insecure -w "\n%{http_code}" $AUTH -XPUT "$ES_HOST/$INDEX" \
  -H "Content-Type: application/json" \
  --cacert config/certs/ca/ca.crt \
  -d @"$MAPPING_FILE")

RESP_BODY=$(echo "$CREATE_RESP" | sed '$d')
HTTP_CODE=$(echo "$CREATE_RESP" | tail -n1)

if [[ "$HTTP_CODE" != "200" && "$HTTP_CODE" != "201" ]]; then
  echo "Failed to create index. HTTP code: $HTTP_CODE"
  echo "Response body:"
  echo "$RESP_BODY"
  exit 1
fi

# Prepare and ingest bulk data in batches of 1000
echo "Ingesting data to $INDEX in batches of 1000..."

awk -F, 'NR==1{for(i=1;i<=NF;i++)h[i]=$i; next}
{
  printf("{\"index\":{}}\n");
  printf("{");
  for(i=1;i<=NF;i++){
    key=h[i];
    val=$i;
    if(val == "" || val == "\"\""){
      printf("\"%s\":null", key);
    } else if(key=="close" || key=="open" || key=="high" || key=="low"){
      printf("\"%s\":%s", key, val); # float, no quotes
    } else if(key=="volume"){
      printf("\"%s\":%d", key, val); # long, no quotes
    } else {
      printf("\"%s\":\"%s\"", key, val); # date/keyword, keep quotes
    }
    if(i<NF)printf(",");
  }
  printf("}\n");
}' "$CSV_FILE" | split -l 2000 - /tmp/bulk_stocks_batch_

for batch in /tmp/bulk_stocks_batch_*; do
  BULK_RESP=$(curl -s  --insecure $AUTH -XPOST "$ES_HOST/$INDEX/_bulk" \
    -H "Content-Type: application/x-ndjson" \
    --cacert config/certs/ca/ca.crt \
    --data-binary @"$batch")
  if echo "$BULK_RESP" | grep -q '"errors":true'; then
    echo "Bulk ingest failed in batch"
    echo "$BULK_RESP" | jq -c '.items[] | select(.index.error) | {error: .index.error.reason, document: .index}'
    exit 1
  fi
  echo "Batch $batch ingested successfully."
done

echo "All batches ingested successfully!"
