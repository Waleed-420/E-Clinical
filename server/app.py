from flask import Flask, request, jsonify
from flask_pymongo import PyMongo
from bson.objectid import ObjectId
from datetime import datetime
import bcrypt
from flask_cors import CORS
import re
import socket

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

# MongoDB configuration
app.config["MONGO_URI"] = "mongodb://localhost:27017/healthcare_app"
mongo = PyMongo(app)

# Email validation regex
EMAIL_REGEX = re.compile(r'^[a-zA-Z0-9.+_-]+@[a-zA-Z0-9._-]+\.[a-zA-Z]{2,}$')
PASSWORD_MIN_LENGTH = 6

@app.route('/api/signup', methods=['POST'])
def signup():
    try:
        data = request.get_json()
        if not data:
            return jsonify({'success': False, 'message': 'No data received'}), 400
        
        required_fields = ['name', 'dob', 'email', 'gender', 'password', 'confirmPassword', 'role']
        missing_fields = [field for field in required_fields if field not in data or not data[field]]
        if missing_fields:
            return jsonify({
                'success': False,
                'message': f'Missing required fields: {", ".join(missing_fields)}'
            }), 400
        
        if not EMAIL_REGEX.match(data['email']):
            return jsonify({
                'success': False,
                'message': 'Invalid email format. Please use a valid email address'
            }), 400
        
        if len(data['password']) < PASSWORD_MIN_LENGTH:
            return jsonify({
                'success': False,
                'message': f'Password must be at least {PASSWORD_MIN_LENGTH} characters'
            }), 400
        
        if data['password'] != data['confirmPassword']:
            return jsonify({
                'success': False,
                'message': 'Passwords do not match'
            }), 400
        
        if mongo.db.users.find_one({'email': data['email']}):
            return jsonify({
                'success': False,
                'message': 'Email already registered. Please use a different email or login'
            }), 400
        
        try:
            dob = datetime.strptime(data['dob'], '%Y-%m-%d')
            if dob > datetime.now():
                return jsonify({
                    'success': False,
                    'message': 'Date of birth cannot be in the future'
                }), 400
        except ValueError:
            return jsonify({
                'success': False,
                'message': 'Invalid date format. Please use YYYY-MM-DD'
            }), 400
        
        hashed_password = bcrypt.hashpw(data['password'].encode('utf-8'), bcrypt.gensalt())
        
        user = {
            'name': data['name'].strip(),
            'dob': dob,
            'email': data['email'].lower().strip(),
            'gender': data['gender'],
            'password': hashed_password.decode('utf-8'),
            'role': data['role'],
            'created_at': datetime.utcnow(),
            'updated_at': datetime.utcnow(),
            'verified': False
        }
        
        result = mongo.db.users.insert_one(user)
        user['_id'] = str(result.inserted_id)
        del user['password']
        
        return jsonify({
            'success': True,
            'message': 'Registration successful!',
            'user': user
        }), 201
        
    except Exception as e:
        return jsonify({
            'success': False,
            'message': 'An unexpected error occurred. Please try again later.'
        }), 500

@app.route('/api/check_email', methods=['POST'])
def check_email():
    try:
        data = request.get_json()
        if not data or 'email' not in data:
            return jsonify({
                'success': False,
                'message': 'Email is required'
            }), 400
        
        if not EMAIL_REGEX.match(data['email']):
            return jsonify({
                'success': False,
                'message': 'Invalid email format'
            }), 400
        
        exists = mongo.db.users.find_one({'email': data['email'].lower().strip()})
        return jsonify({
            'success': True,
            'exists': exists is not None,
            'message': 'Email already registered' if exists else 'Email available'
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'message': 'An error occurred while checking email'
        }), 500

@app.route('/api/health', methods=['GET'])
def health_check():
    return jsonify({
        'success': True,
        'status': 'Server is running',
        'server_ip': socket.gethostbyname(socket.gethostname()),
        'timestamp': datetime.utcnow().isoformat()
    }), 200

    
@app.route('/api/signin', methods=['POST'])
def signin():
    try:
        data = request.get_json()
        if not data or 'email' not in data or 'password' not in data:
            return jsonify({'success': False, 'message': 'Email and password required'}), 400

        user = mongo.db.users.find_one({'email': data['email'].lower().strip()})
        if not user:
            return jsonify({'success': False, 'message': 'Invalid email or password'}), 401

        if not bcrypt.checkpw(data['password'].encode('utf-8'), user['password'].encode('utf-8')):
            return jsonify({'success': False, 'message': 'Invalid email or password'}), 401

        user['_id'] = str(user['_id'])
        del user['password']
        return jsonify({'success': True, 'message': 'Login successful', 'user': user}), 200
    except Exception as e:
        return jsonify({'success': False, 'message': 'Server error'}), 500
if __name__ == '__main__':
    app.run(
        host='192.168.100.104',
        port=5000,
        debug=True
    )