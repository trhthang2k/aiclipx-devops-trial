import logging
import os
import time

from flask import Flask, g, jsonify, request
from pythonjsonlogger import jsonlogger
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest

app = Flask(__name__)

# Structured JSON logging to stdout
logger = logging.getLogger()
logHandler = logging.StreamHandler()
formatter = jsonlogger.JsonFormatter('%(asctime)s %(levelname)s %(name)s %(message)s')
logHandler.setFormatter(formatter)
logger.addHandler(logHandler)
logger.setLevel(logging.INFO)

# Prometheus metrics
REQUEST_COUNT = Counter('app_requests_total', 'Total HTTP requests', ['method', 'endpoint', 'http_status'])
REQUEST_LATENCY = Histogram('app_request_latency_seconds', 'Request latency', ['endpoint'])
ERROR_COUNT = Counter('app_errors_total', 'Total errors')

# In-memory store (proof of concept)
items = []
next_id = 1

# readiness flag
ready = True


def record_request(endpoint, method, status, latency=None):
    REQUEST_COUNT.labels(method=method, endpoint=endpoint, http_status=str(status)).inc()
    if latency is not None:
        REQUEST_LATENCY.labels(endpoint=endpoint).observe(latency)


# Automatic timing and request recording via Flask hooks
@app.before_request
def before_request():
    g.start_time = time.time()


@app.after_request
def after_request(response):
    # skip recording metrics for metrics endpoint to avoid scrape recursion
    try:
        path = request.path
    except Exception:
        path = '/'
    if path != '/metrics':
        latency = None
        if hasattr(g, 'start_time'):
            latency = time.time() - g.start_time
        REQUEST_COUNT.labels(method=request.method, endpoint=path, http_status=str(response.status_code)).inc()
        if latency is not None:
            REQUEST_LATENCY.labels(endpoint=path).observe(latency)
    return response


@app.teardown_request
def teardown_request(exc):
    # increment error counter for unhandled exceptions
    if exc is not None:
        ERROR_COUNT.inc()


@app.route('/', methods=['GET'])
def index():
    logger.info('index called', extra={'endpoint': '/'})
    record_request('/', 'GET', 200)
    return jsonify({'service': 'aiClipx-trial', 'status': 'ok'})


@app.route('/items', methods=['GET'])
def list_items():
    logger.info('list items', extra={'endpoint': '/items'})
    record_request('/items', 'GET', 200)
    return jsonify({'items': items})


@app.route('/items', methods=['POST'])
def create_item():
    global next_id
    try:
        payload = request.get_json(force=True)
        name = payload.get('name')
        if not name:
            logger.warning('create_item missing name', extra={'payload': payload})
            record_request('/items', 'POST', 400)
            return jsonify({'error': 'name is required'}), 400
        item = {'id': next_id, 'name': name}
        next_id += 1
        items.append(item)
        logger.info('item created', extra={'item': item})
        record_request('/items', 'POST', 201)
        return jsonify(item), 201
    except Exception:
        logger.exception('create_item failed')
        ERROR_COUNT.inc()
        record_request('/items', 'POST', 500)
        return jsonify({'error': 'internal error'}), 500


@app.route('/health/live', methods=['GET'])
def liveness():
    # Liveness checks that the process is running
    record_request('/health/live', 'GET', 200)
    return jsonify({'live': True})


@app.route('/health/ready', methods=['GET'])
def readiness():
    # Readiness: check core app state (simple flag here)
    status = 200 if ready else 503
    record_request('/health/ready', 'GET', status)
    return jsonify({'ready': ready}), status


@app.route('/metrics', methods=['GET'])
def metrics():
    # Expose Prometheus metrics
    resp = generate_latest()
    return (resp, 200, {'Content-Type': CONTENT_TYPE_LATEST})


if __name__ == '__main__':
    # Local dev server (not used in Docker production image)
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))
