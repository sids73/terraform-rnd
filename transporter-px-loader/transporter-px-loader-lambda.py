import boto3
import json
print(f"Using Boto3 version: {boto3.__version__}")

def event_handler(event, context):
    print(f"Received event: {event}")
    print(f"Received context: {context}")
    process_config_change()
    return {
        'statusCode': 200,
        'body': json.dumps('Handled Transporter PX config change event from S3 in Lambda!')
    }

from botocore.exceptions import ClientError

# Initialize the boto3 client for MSK Connect
client = boto3.client('kafkaconnect')

def update_connector(connector_arn):
        # Get the current version of the connector
    try:
        response = client.describe_connector(
            connectorArn=connector_arn
        )
        current_version = response['currentVersion']
        print(f"Current connector version: {current_version}")

    except ClientError as e:
        print(f"Error retrieving connector details: {e}")
        return

    
    # Update the MSK Connect connector with mandatory and updated fields
    try:
        response = client.update_connector(
            # capacity=capacity_request,
            connectorConfiguration={ "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
                "database.dbname": "ecommerce",
                "database.user": "${secretsmanager:application/debezium_postgre_kafka_sink:username}",
                "slot.name": "debezium",
                "tasks.max": "1",
                "schema.include.list": "public",
                "plugin.name": "pgoutput",
                "database.port": "${secretsmanager:application/debezium_postgre_kafka_sink:port}",
                "topic.prefix": "ecommerce-cdc",
                "database.hostname": "${secretsmanager:application/debezium_postgre_kafka_sink:host}",
                "database.password": "${secretsmanager:application/debezium_postgre_kafka_sink:password}",
                "name": "ecommerce-cdc",
                "table.include.list": "public.customers,public.orders",
                "test": "msk_test"},
            connectorArn=connector_arn,
            currentVersion=current_version)
        
        # Print the response
        print("Transporter GKS Sink MSK Connect Connector Updated Successfully:")
        print(response)
        
    except ClientError as e:
        print(f"Error updating the connector: {e}")


def process_config_change():
    # Define the ARN of the connector you want to update
    connector_arn = 'arn:aws:kafkaconnect:us-east-1:173881142689:connector/ecommerce-cdc/0d897e8a-83c2-48ee-b616-37d1b4d51c0b-2'
    update_connector(connector_arn)