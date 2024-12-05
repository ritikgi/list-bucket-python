from flask import Flask, jsonify
import boto3
from botocore.exceptions import ClientError

app = Flask(__name__)

# Initialize S3 client
s3 = boto3.client('s3')

BUCKET_NAME = "one2n-mybucket"  # Your S3 bucket name

@app.route('/list-bucket-content', defaults={'path': ''}, methods=['GET'])
@app.route('/list-bucket-content/<path:path>', methods=['GET'])
def list_bucket_content(path):
    try:
        # Normalize path to ensure it ends with a slash for directory queries
        if path and not path.endswith('/'):
            path += '/'

        # List objects under the given path
        response = s3.list_objects_v2(Bucket=BUCKET_NAME, Prefix=path, Delimiter='/')

        # Check if the path exists by verifying 'Contents' or 'CommonPrefixes'
        if 'Contents' not in response and 'CommonPrefixes' not in response:
            return jsonify({"error": f"The path '{path.rstrip('/')}' does not exist."}), 404

        content = []

        # Root level (no path provided): list directories
        if path == '':
            if 'CommonPrefixes' in response:
                content.extend([item['Prefix'].rstrip('/').split('/')[-1] for item in response['CommonPrefixes']])
            return jsonify({"content": content})

        # Subdirectories: list files directly under the path
        if 'Contents' in response:
            content.extend([item['Key'].split('/')[-1] for item in response['Contents'] if item['Key'] != path])

        # Return content
        return jsonify({"content": content or []})

    except ClientError as e:
        return jsonify({"error": f"An AWS error occurred: {e.response['Error']['Message']}"}), 500
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
