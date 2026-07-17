import atexit
from flask import Flask
from routes.prediction import prediction_bp
from routes.alert import alert_bp
from routes.sms import sms_bp
from routes.remind import remind_bp
from services.scheduler_service import scheduler

app = Flask(__name__)
app.register_blueprint(prediction_bp)
app.register_blueprint(alert_bp)
app.register_blueprint(sms_bp)
app.register_blueprint(remind_bp)

atexit.register(lambda: scheduler.shutdown(wait=False))

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
