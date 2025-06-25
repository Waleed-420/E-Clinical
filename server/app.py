from flask import Flask, request, jsonify
from flask_pymongo import PyMongo
from bson.objectid import ObjectId
from datetime import datetime, timedelta
import bcrypt
from flask_cors import CORS
import re
import socket
import os
import pytesseract
from PIL import Image
from pdf2image import convert_from_bytes
import io
from apscheduler.schedulers.background import BackgroundScheduler
import firebase_admin
from firebase_admin import credentials, messaging
from agora_token_builder import RtcTokenBuilder
from apscheduler.schedulers.base import SchedulerAlreadyRunningError
from pytz import timezone
import time


app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

cred = credentials.Certificate("./serviceAccountKey.json")
firebase_admin.initialize_app(cred)

AGORA_APP_ID = 'dff72470ec104f92aa6cc17e36337822'
AGORA_APP_CERTIFICATE = '007eJxTYPj7fo2ZmvXBkz+Svy64FJwp+CzJ87f1PBu1X0kMW1JXex9XYLA0Tku0SLVMTTY0MTOxNLVMTEqxNDFMM0wzNk0yNTE3EFaKzGgIZGQwutPLzMgAgSA+B0OqbnJOZl5mMgMDAE27IW0='

# MongoDB configuration
app.config["MONGO_URI"] = "mongodb://localhost:27017/healthcare_app"
mongo = PyMongo(app)
# print mongo db connected
pkt = timezone('Asia/Karachi')



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
                'message': 'Invalid email format. Please use a valid email address.'
            }), 400

        if len(data['password']) < PASSWORD_MIN_LENGTH:
            return jsonify({
                'success': False,
                'message': f'Password must be at least {PASSWORD_MIN_LENGTH} characters.'
            }), 400

        if data['password'] != data['confirmPassword']:
            return jsonify({
                'success': False,
                'message': 'Passwords do not match.'
            }), 400

        if mongo.db.users.find_one({'email': data['email'].lower().strip()}):
            return jsonify({
                'success': False,
                'message': 'Email already registered. Please use a different email or login.'
            }), 400

        try:
            dob = pkt.localize(datetime.strptime(data['dob'], '%Y-%m-%d'))
            if dob > datetime.now(pkt):
                return jsonify({
                    'success': False,
                    'message': 'Date of birth cannot be in the future.'
                }), 400
        except ValueError:
            return jsonify({
                'success': False,
                'message': 'Invalid date format. Please use YYYY-MM-DD.'
            }), 400

        hashed_password = bcrypt.hashpw(data['password'].encode('utf-8'), bcrypt.gensalt())

        user = {
            'name': data['name'].strip(),
            'dob': dob,
            'email': data['email'].lower().strip(),
            'gender': data['gender'],
            'password': hashed_password.decode('utf-8'),
            'role': data['role'],
            'balance': 0,
            'created_at': datetime.now(pkt),
            'updated_at': datetime.now(pkt),
            'verified': False
        }

        if data['role'].strip().lower() == 'doctor':
            user['fee'] = 500

        result = mongo.db.users.insert_one(user)
        user['_id'] = str(result.inserted_id)
        del user['password']

        return jsonify({
            'success': True,
            'message': 'Registration successful!',
            'user': user
        }), 201

    except Exception as e:
        import traceback
        traceback.print_exc()  # <-- this prints the full error in your terminal
        return jsonify({
            'success': False,
            'message': f'Internal Server Error: {str(e)}'
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
        'timestamp': datetime.now(pkt).isoformat()
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


pytesseract.pytesseract.tesseract_cmd = r'C:\Program Files\Tesseract-OCR\tesseract.exe'

# Email validation regex
EMAIL_REGEX = re.compile(r'^[a-zA-Z0-9.+_-]+@[a-zA-Z0-9._-]+\.[a-zA-Z]{2,}$')
PASSWORD_MIN_LENGTH = 6

# medical reports api 
MEDICAL_KEYWORDS = [
    'patient', 'doctor', 'hospital', 'diagnosis', 'prescription', 
    'medication', 'treatment', 'blood', 'test', 'report',
    'lab', 'x-ray', 'mri', 'scan', 'clinical', 'health',
    'medical', 'history', 'allergy', 'disease', 'condition',
    'physician', 'nurse', 'vitals', 'symptoms', 'findings',
    'impression', 'recommendation', 'assessment', 'plan'
]

def is_medical_report(text):
    if not text:
        return False
    text_lower = text.lower()
    keyword_count = sum(1 for keyword in MEDICAL_KEYWORDS if keyword in text_lower)
    has_patient_info = ('name' in text_lower or 'dob' in text_lower or 'age' in text_lower)
    has_medical_terms = keyword_count >= 3
    has_report_structure = ('report' in text_lower or 'results' in text_lower or 'findings' in text_lower)
    return has_patient_info or (has_medical_terms and has_report_structure)

def extract_text_from_image(image_bytes):
    try:
        image = Image.open(io.BytesIO(image_bytes)).convert("RGB")  # Force to RGB
        text = pytesseract.image_to_string(image)
        return text.strip()
    except UnidentifiedImageError:
        raise Exception("Unsupported image format. Try JPG or PNG.")
    except Exception as e:
        raise Exception(f"Image processing failed: {str(e)}")

def extract_text_from_pdf(pdf_bytes):
    try:
        images = convert_from_bytes(pdf_bytes)
        full_text = ""
        for i, image in enumerate(images):
            text = pytesseract.image_to_string(image)
            full_text += f"Page {i+1}:\n{text}\n\n"
        return full_text.strip()
    except Exception as e:
        raise Exception(f"PDF processing failed: {str(e)}")

def parse_medical_report(text):
    import re
    lines = text.splitlines()
    report_data = {
        'institute_name': None,
        'date': None,
        'tests': []
    }

    for line in lines:
        if not report_data['date']:
            try:
                parsed_date = dateutil.parser.parse(line, fuzzy=True)
                report_data['date'] = parsed_date.strftime('%Y-%m-%d')
            except:
                pass
        if not report_data['institute_name']:
            if 'hospital' in line.lower() or 'clinic' in line.lower() or 'lab' in line.lower():
                report_data['institute_name'] = line.strip()

    # Improved regex-based table parsing
    for line in lines:
        # Match patterns like: "Hemoglobin 10.7 gm/dl 11.5-15"
        match = re.match(
            r'^([A-Za-z ()%]+)\s+([\d.]+)\s+([a-zA-Z/%^0-9]+)\s+([\d.\-]+[\s\-to]+[\d.]+)', line.strip()
        )
        if match:
            test = {
                'field': match.group(1).strip(),
                'value': match.group(2).strip(),
                'unit': match.group(3).strip(),
                'normal_range': match.group(4).strip().replace("to", "-")
            }
            report_data['tests'].append(test)
        else:
            # Fallback: match simpler pattern like: "Calcium 4.4 mg/dl 8.8-10.6"
            parts = re.split(r'\s{2,}', line.strip())
            if len(parts) == 3:
                test = {
                    'field': parts[0],
                    'value': parts[1],
                    'unit': '',
                    'normal_range': parts[2]
                }
                report_data['tests'].append(test)

    return report_data

@app.route('/api/scan-medical-report', methods=['POST'])
def scan_medical_report():
    if 'document' not in request.files:
        return jsonify({'success': False, 'message': 'No file uploaded'}), 400
    
    file = request.files['document']
    if file.filename == '':
        return jsonify({'success': False, 'message': 'No selected file'}), 400

    try:
        file_bytes = file.read()
        filename = file.filename.lower()

        if filename.endswith(('.jpg', '.jpeg', '.png', '.bmp', '.tiff', '.heic')):
            extracted_text = extract_text_from_image(file_bytes)
        elif filename.endswith('.pdf'):
            extracted_text = extract_text_from_pdf(file_bytes)
        else:
            return jsonify({'success': False, 'message': 'Unsupported file type. Upload JPG, PNG, or PDF'}), 400

        if not extracted_text:
            return jsonify({'success': False, 'message': 'No text could be extracted'}), 400

        is_medical = is_medical_report(extracted_text)
        medical_keywords_found = [kw for kw in MEDICAL_KEYWORDS if kw in extracted_text.lower()]
        parsed_data = parse_medical_report(extracted_text)

        return jsonify({
            'success': True,
            'isMedicalReport': is_medical,
            'extractedText': extracted_text,
            'structuredData': parsed_data,
            'medicalKeywordsFound': medical_keywords_found,
            'message': 'Medical report processed' if is_medical else 'Document processed (not clearly medical)'
        }), 200
    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': f'Error processing document: {str(e)}'}), 500








#doctor APi


# Doctor endpoints
@app.route('/api/upload-license', methods=['POST'])
def upload_license():
    if 'license' not in request.files:
        return jsonify({'success': False, 'message': 'No file uploaded'}), 400
    
    file = request.files['license']
    user_id = request.form.get('userId')
    email = request.form.get('email')

    # Validate and process license file
    # Save to MongoDB
    # Update doctor verification status
    
    return jsonify({
        'success': True,
        'message': 'License received for verification',
        'verified': False  # Set to True after manual/admin verification
    })

@app.route('/api/doctor/schedule', methods=['POST'])
def save_doctor_schedule():
    data = request.get_json()
    doctor_id = data.get('doctorId')
    name = data.get('name')
    specialization = data.get('specialization')
    schedule = data.get('schedule')

    # Save to MongoDB
    mongo.db.doctors.update_one(
        {'_id': ObjectId(doctor_id)},
        {'$set': {
            'name': name,
            'schedule': schedule,
            'specialization': specialization,
            'verified': True,
            'updated_at': datetime.now(pkt)
        }},
        upsert=True
    )

    mongo.db.users.update_one(
        {'_id': ObjectId(doctor_id)},
        {'$set': {
            'name': name,
            'schedule': schedule,
            'specialization': specialization,
            'verified': True,
            'updated_at': datetime.now(pkt)
        }},
        upsert=True
    )

    return jsonify({'success': True, 'message': 'Schedule saved'})

# Appointment endpoints
@app.route('/api/doctors', methods=['GET'])
def get_doctors():
    specialization = request.args.get('specialization')
    query = {'verified': True}
    if specialization:
        query['specialization'] = specialization
    
    users = list(mongo.db.users.find(query, {
        '_id': 1,
        'name': 1,
        'specialization': 1,
        'schedule': 1
    }))
    
    for doc in users:
        doc['_id'] = str(doc['_id'])
    
    return jsonify({'success': True, 'doctors': users})

@app.route('/api/doctor/<doctor_id>/specialization/slots', methods=['GET'])
def get_available_slots(doctor_id):
    try:
        date_str = request.args.get('date')
        if not date_str:
            return jsonify({'success': False, 'message': 'Date parameter is required'}), 400

        try:
            date = datetime.strptime(date_str, '%Y-%m-%d')
        except ValueError:
            return jsonify({'success': False, 'message': 'Invalid date format. Use YYYY-MM-DD'}), 400

        if not ObjectId.is_valid(doctor_id):
            return jsonify({'success': False, 'message': 'Invalid doctor ID format'}), 400

        doctor = mongo.db.doctors.find_one({'_id': ObjectId(doctor_id)})
        if not doctor:
            return jsonify({'success': False, 'message': 'Doctor not found'}), 404

        # Get booked times
        booked_appointments = list(mongo.db.appointments.find({
            'doctorId': doctor_id,
            'date': date_str,
            'status': {'$in': ['booked', 'confirmed']}
        }))
        booked_times = {appt['time'] for appt in booked_appointments if 'time' in appt}

        # Collect schedule for the day
        weekday = str(date.isoweekday())  # Monday=1
        schedule = doctor.get('schedule', {}).get(weekday, [])

        # Use a set to avoid duplicates
        available_slots_set = set()

        for slot in schedule:
            try:
                start_time = datetime.strptime(slot['start'], '%H:%M').time()
                end_time = datetime.strptime(slot['end'], '%H:%M').time()
                current = datetime.combine(date, start_time)
                end = datetime.combine(date, end_time)

                while current < end:
                    slot_str = current.strftime('%H:%M')
                    if slot_str not in booked_times:
                        available_slots_set.add(slot_str)
                    current += timedelta(minutes=30)
            except Exception as e:
                app.logger.error(f"Error processing slot: {str(e)}")
                continue

        # Convert set to sorted list
        available_slots = sorted(available_slots_set)

        return jsonify({
            'success': True,
            'slots': available_slots,
            'date': date_str,
            'doctor_id': doctor_id
        }), 200

    except Exception as e:
        app.logger.error(f"Error in get_available_slots: {str(e)}\n{traceback.format_exc()}")
        return jsonify({
            'success': False,
            'message': 'An error occurred while fetching available slots',
            'error': str(e)
        }), 500

@app.route('/api/appointments', methods=['POST'])
def book_appointment():
    try:
        if not request.is_json:
            return jsonify({'success': False, 'message': 'Request must be JSON'}), 400

        data = request.get_json()

        # Validate required fields
        required_fields = ['userId', 'doctorId', 'date', 'time']
        missing_fields = [field for field in required_fields if not data.get(field)]
        if missing_fields:
            return jsonify({
                'success': False,
                'message': f"Missing required fields: {', '.join(missing_fields)}"
            }), 400

        # Validate doctorId
        if not ObjectId.is_valid(data['doctorId']):
            return jsonify({'success': False, 'message': 'Invalid doctor ID format'}), 400

        # Validate user
        user = mongo.db.users.find_one({'_id': ObjectId(data['userId'])})
        if not user:
            return jsonify({'success': False, 'message': 'User not found'}), 404

        # check user balance 
        if user.get('balance', 0) < data.get('fee', 0):
            return jsonify({'success': False, 'message': 'Insufficient balance'}), 400

        doctor = mongo.db.users.find_one({'_id': ObjectId(data['doctorId'])})
        if not doctor:
            return jsonify({'success': False, 'message': 'Doctor not found'}), 404

        # Validate date format
        try:
            datetime.strptime(data['date'], '%Y-%m-%d')
        except ValueError:
            return jsonify({'success': False, 'message': 'Invalid date format. Use YYYY-MM-DD'}), 400

        # Check if the slot is already booked
        already_booked = mongo.db.appointments.find_one({
            'doctorId': data['doctorId'],
            'date': data['date'],
            'time': data['time'],
            'status': {'$in': ['booked', 'confirmed']}
        })
        if already_booked:
            return jsonify({'success': False, 'message': 'This time slot is already booked'}), 400

        # Create chat
        channel = data['doctorId'] + data['userId']
        chat = {
            'userId': data['userId'],
            'doctorId': data['doctorId'],
            'channel': channel,
            'messages': [],  # Empty message list for now
            'appointmentTime': data['time'],
            'appointmentDate': data['date'],
            'created_at': datetime.now(pkt),
            'updated_at': datetime.now(pkt)
        }
        mongo.db.chats.insert_one(chat)

        # Create appointment
        appointment = {
            'userId': data['userId'],
            'doctorId': data['doctorId'],
            'doctorName': doctor.get('name'),
            'date': data['date'],
            'time': data['time'],
            'payment': data.get('payment'),  # Optional
            'status': 'booked',
            'fee': doctor.get('fee'),
            'channel': channel,
            'created_at': datetime.now(pkt),
            'updated_at': datetime.now(pkt),
            'reminderSent': False
        }

        result = mongo.db.appointments.insert_one(appointment)
        appointment['_id'] = str(result.inserted_id)

        # update doctor balance
        mongo.db.users.update_one(
            {'_id': ObjectId(data['doctorId'])},
            {'$inc': {'balance': doctor.get('fee')}}
        )

        # update user balance
        mongo.db.users.update_one(
            {'_id': ObjectId(data['userId'])},
            {'$inc': {'balance': -doctor.get('fee')}}
        )

        return jsonify({
            'success': True,
            'message': 'Appointment booked successfully',
            'appointment': appointment
        }), 201

    except Exception as e:
        app.logger.error(f"Error in book_appointment: {str(e)}\n{traceback.format_exc()}")
        return jsonify({
            'success': False,
            'message': 'An error occurred while booking appointment',
            'error': str(e)
        }), 500

# new branch
@app.route('/api/doctor/<doctor_id>/specialization', methods=['GET'])
def get_doctor_specialization(doctor_id):
    if not ObjectId.is_valid(doctor_id):
        return jsonify({'success': False, 'message': 'Invalid doctor ID'}), 400

    doctor = mongo.db.doctors.find_one(
        {'_id': ObjectId(doctor_id)},
        {'specialization': 1}
    )

    if not doctor:
        return jsonify({'success': False, 'message': 'Doctor not found'}), 404
    
    return jsonify({
        'success': True,
        'specialization': doctor.get('specialization', None)
    }), 200

@app.route('/api/doctor/<doctor_id>/schedule', methods=['GET'])
def get_doctor_schedule(doctor_id):
    if not ObjectId.is_valid(doctor_id):
        return jsonify({'success': False, 'message': 'Invalid doctor ID'}), 400

    doctor = mongo.db.doctors.find_one({'_id': ObjectId(doctor_id)}, {'schedule': 1})
    if not doctor:
        return jsonify({'success': False, 'message': 'Doctor not found'}), 404

    return jsonify({'success': True, 'schedule': doctor.get('schedule', {})}), 200

@app.route('/api/doctor/<doctor_id>/specialization', methods=['POST'])
def update_doctor_specialization(doctor_id):
    if not ObjectId.is_valid(doctor_id):
        return jsonify({'success': False, 'message': 'Invalid doctor ID'}), 400

    data = request.get_json()
    specialization = data.get('specialization')
    
    if not specialization:
        return jsonify({'success': False, 'message': 'Specialization is required'}), 400

    # Update in users collection (primary)
    mongo.db.users.update_one(
        {'_id': ObjectId(doctor_id), 'role': 'Doctor'},
        {'$set': {
            'specialization': specialization,
            'updated_at': datetime.now(pkt)
        }}
    )

    # Update in doctors collection (secondary)
    mongo.db.doctors.update_one(
        {'_id': ObjectId(doctor_id)},
        {'$set': {
            'specialization': specialization,
            'updated_at': datetime.now(pkt)
        }},
        upsert=True
    )

    return jsonify({'success': True, 'message': 'Specialization updated'}), 200

@app.route('/api/doctor/<doctor_id>/slots', methods=['GET'])

def get_doctor_slots(doctor_id):
    try:
        date_str = request.args.get('date')
        if not date_str:
            return jsonify({'success': False, 'message': 'Date parameter is required'}), 400

        try:
            date = datetime.strptime(date_str, '%Y-%m-%d')
        except ValueError:
            return jsonify({'success': False, 'message': 'Invalid date format. Use YYYY-MM-DD'}), 400

        weekday = str(date.isoweekday())

        if not ObjectId.is_valid(doctor_id):
            return jsonify({'success': False, 'message': 'Invalid doctor ID'}), 400

        doctor = mongo.db.doctors.find_one({'_id': ObjectId(doctor_id)})
        if not doctor:
            return jsonify({'success': False, 'message': 'Doctor not found'}), 404

        booked = list(mongo.db.appointments.find({
            'doctorId': doctor_id,
            'date': date_str,
            'status': {'$in': ['booked', 'confirmed']}
        }))

        booked_times = {appt.get('time') for appt in booked if appt.get('time')}

        schedule = doctor.get('schedule', {}).get(weekday, [])
        if not isinstance(schedule, list):
            return jsonify({'success': False, 'message': 'Invalid schedule format'}), 500

        slot_ranges = []

        for slot in schedule:
            try:
                start_time = datetime.strptime(slot['start'], '%H:%M').time()
                end_time = datetime.strptime(slot['end'], '%H:%M').time()
            except (KeyError, ValueError):
                continue

            current = datetime.combine(date, start_time)
            end = datetime.combine(date, end_time)

            available_times = []
            while current < end:
                slot_str = current.strftime('%H:%M')
                if slot_str not in booked_times:
                    available_times.append({'time': slot_str})
                current += timedelta(minutes=30)

            if available_times:
                slot_ranges.append({
                    'start': slot.get('start'),
                    'end': slot.get('end'),
                    'slots': available_times
                })

        return jsonify({
            'success': True,
            'date': date_str,
            'slots': slot_ranges
        }), 200

    except Exception as e:
        return jsonify({
            'success': False,
            'message': 'Internal server error',
            'error': str(e)
        }), 500



@app.route('/api/user/<user_id>/appointments', methods=['GET'])
def get_user_appointments(user_id):
    if not ObjectId.is_valid(user_id):
        return jsonify({'success': False, 'message': 'Invalid user ID'}), 400

    user = mongo.db.users.find_one({'_id': ObjectId(user_id)})
    if not user:
        return jsonify({'success': False, 'message': 'User not found'}), 404

    role = user.get('role')
    appointments = []

    if role == 'General User':
        appointments = list(mongo.db.appointments.find({'userId': str(user['_id'])}))
        for appt in appointments:
            doctor = mongo.db.users.find_one({'_id': ObjectId(appt['doctorId'])})
            appt['otherName'] = doctor.get('name', 'Unknown Doctor') if doctor else 'Unknown Doctor'
            appt['otherFcmToken'] = doctor.get('deviceToken', '') if doctor else ''

    elif role == 'Doctor':
        appointments = list(mongo.db.appointments.find({'doctorId': str(user['_id'])}))
        for appt in appointments:
            try:
                patient = mongo.db.users.find_one({'_id': ObjectId(appt['userId'])})
                appt['otherName'] = patient.get('name', 'Unknown Patient') if patient else 'Unknown Patient'
                appt['otherFcmToken'] = patient.get('deviceToken', '') if patient else ''
            except Exception:
                appt['otherName'] = 'Unknown'
                appt['otherFcmToken'] = ''

    else:
        return jsonify({'success': False, 'message': 'Invalid user role'}), 400

    # Optional: Add sorting by datetime if date and time exist
    def parse_datetime(appt):
        try:
            return datetime.strptime(f"{appt.get('date')} {appt.get('time')}", "%Y-%m-%d %H:%M")
        except:
            return datetime.min

    appointments.sort(key=parse_datetime)

    for appt in appointments:
        appt['_id'] = str(appt['_id'])  # convert ObjectId to string

    return jsonify({'success': True, 'appointments': appointments}), 200

@app.route('/api/save-token', methods=['POST'])
def save_device_token():
    data = request.json
    user_id = data.get('userId')
    token = data.get('deviceToken')

    if not user_id or not token:
        return jsonify({'success': False, 'message': 'Missing data'}), 400

    collection = mongo.db.users
    result = collection.update_one(
        {'_id': ObjectId(user_id)},
        {'$set': {'deviceToken': token}}
    )

    if result.modified_count == 1:
        return jsonify({'success': True, 'message': 'Token saved'})
    else:
        return jsonify({'success': False, 'message': 'User not found'}), 404


def send_fcm(token, title, body):
    if not token:
        return
    message = messaging.Message(
        notification=messaging.Notification(title=title, body=body),
        token=token,
    )
    messaging.send(message)

scheduler = BackgroundScheduler()
print("[Scheduler] Started")

def check_upcoming_appointments():
    print("[START] check_upcoming_appointments")
    now = datetime.now(pkt)
    print(f"[Scheduler Tick] Current time: {now}")

    today_str = now.strftime('%Y-%m-%d')
    appointments = mongo.db.appointments.find({
        'date': today_str,
        'status': {'$in': ['booked', 'confirmed']},
        'reminderSent': False  # Only get appointments that haven't been reminded
    })

    for appt in appointments:
        try:
            appt_time_str = f"{appt['date']} {appt['time']}"
            appt_naive = datetime.strptime(appt_time_str, "%Y-%m-%d %H:%M")
            appt_local = pkt.localize(appt_naive)

            minutes_until = int((appt_local - now).total_seconds() / 60)
            

            if 4 <= minutes_until <= 6:
                user = mongo.db.users.find_one({'_id': ObjectId(appt['userId'])})
                doctor = mongo.db.users.find_one({'_id': ObjectId(appt['doctorId'])})

                user_name = user.get('name', 'Unknown') if user else 'Unknown User'
                doctor_name = doctor.get('name', 'Unknown') if doctor else 'Unknown Doctor'

                # Log who gets reminded
                if user:
                    print(f"[Reminder: 5 mins] {user_name} with Dr. {doctor_name} at {appt['time']}")
                if doctor:
                    print(f"[Reminder: 5 mins] Dr. {doctor_name} with {user_name} at {appt['time']}")

                # Send reminders
                if user:
                    send_fcm(user.get('deviceToken'), "Appointment in 5 minutes",
                             f"Your appointment with Dr. {doctor_name} is at {appt['time']}.")
                if doctor:
                    send_fcm(doctor.get('deviceToken'), "Appointment in 5 minutes",
                             f"You have an appointment with {user_name} at {appt['time']}.")

                # Mark reminsend_fcder as sent
                mongo.db.appointments.update_one(
                    {'_id': appt['_id']},
                    {'$set': {'reminderSent': True}}
                )

        except Exception as e:
            app.logger.error(f"Error in reminder logic: {str(e)}")

try:
    scheduler.add_job(check_upcoming_appointments, 'interval', minutes=1)
    scheduler.start()
except SchedulerAlreadyRunningError:
    pass

@app.route('/api/start-call', methods=['POST'])
def start_call():
    data = request.json
    channel_name = data['channelName']
    uid = 0
    expire_time = int(time.time()) + 1800

    token = RtcTokenBuilder.buildTokenWithUid(
        AGORA_APP_ID, AGORA_APP_CERTIFICATE,
        channel_name, uid, 1, expire_time
    )

    # find appointment through channel name
    appointment = mongo.db.appointments.find_one({'_id': ObjectId(channel_name)})
    if not appointment:
        return jsonify({'success': False, 'message': 'Appointment not found'}), 404

    user = mongo.db.users.find_one({'_id': ObjectId(appointment['userId'])})
    
    # Send push notification to user
    target_token = user.get('deviceToken')
    messaging.send(messaging.Message(
        notification=messaging.Notification(
            title='Incoming Video Call',
            body='Doctor is calling you now.',
        ),
        data={
            'token': token,
            'channelName': channel_name,
        },
        token=target_token,
    ))

    return jsonify({'success': True, 'token': token})

@app.route('/api/chat/channel/<channel>', methods=['GET', 'POST'])
def handle_chat_channel(channel):
    if request.method == 'GET':
        chat = mongo.db.chats.find_one({'channel': channel})
        if not chat:
            return jsonify({'success': False, 'message': 'Chat not found'}), 404

        chat['_id'] = str(chat['_id'])

        # Extract user IDs from channel name
        try:
            user_ids = channel.split('_')
            user_objs = list(mongo.db.users.find({'_id': {'$in': [ObjectId(uid) for uid in user_ids]}}))
            users = [{'_id': str(u['_id']), 'name': u.get('name', 'Unknown')} for u in user_objs]
        except Exception as e:
            users = []

        return jsonify({'success': True, 'chat': chat, 'users': users}), 200

    elif request.method == 'POST':
        chat = mongo.db.chats.find_one({'channel': channel})
        if chat:
            chat['_id'] = str(chat['_id'])
            return jsonify({'success': True, 'chat': chat}), 200

        new_chat = {
            'channel': channel,
            'messages': [],
            'created_at': datetime.now(pkt),
            'updated_at': datetime.now(pkt)
        }
        result = mongo.db.chats.insert_one(new_chat)
        new_chat['_id'] = str(result.inserted_id)
        return jsonify({'success': True, 'chat': new_chat}), 200


@app.route('/api/chat/<chat_id>/messages', methods=['POST'])
def send_message(chat_id):
    try:
        data = request.get_json()
        sender = data.get('sender')
        content = data.get('content')

        if not sender or not content:
            return jsonify({'success': False, 'message': 'Sender and content are required'}), 400

        chat = mongo.db.chats.find_one({'_id': ObjectId(chat_id)})
        if not chat:
            return jsonify({'success': False, 'message': 'Chat not found'}), 404

        message = {
            'sender': sender,
            'content': content,
            'timestamp': datetime.now(pkt).isoformat(),
            'delivered': False  # Make sure previous lines all have commas!
        }

        mongo.db.chats.update_one(
            {'_id': ObjectId(chat_id)},
            {
                '$push': {'messages': message},
                '$set': {'updated_at': datetime.now(pkt)}
            }
        )

        return jsonify({'success': True, 'message': 'Message sent'}), 200

    except Exception as e:
        return jsonify({'success': False, 'message': f'Error sending message: {str(e)}'}), 500


@app.route('/api/chat/<chat_id>/mark-delivered', methods=['POST'])
def mark_messages_delivered(chat_id):
    try:
        user_id = request.json.get('user_id')
        mongo.db.chats.update_one(
            {'_id': ObjectId(chat_id)},
            {'$set': {'messages.$[elem].delivered': True}},
            array_filters=[{'elem.sender': {'$ne': user_id}}]
        )
        return jsonify({'success': True}), 200
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@app.route('/api/appointments/<appointment_id>/rate', methods=['POST'])
def rate_appointment(appointment_id):
    if not ObjectId.is_valid(appointment_id):
        return jsonify({'success': False, 'message': 'Invalid appointment ID'}), 400

    data = request.get_json()
    rating = data.get('rating')
    if not rating or not isinstance(rating, (int, float)) or not (1 <= rating <= 5):
        return jsonify({'success': False, 'message': 'Rating must be a number between 1 and 5'}), 400

    appointment = mongo.db.appointments.find_one({'_id': ObjectId(appointment_id)})
    if not appointment:
        return jsonify({'success': False, 'message': 'Appointment not found'}), 404

    doctor_id = appointment.get('doctorId')
    if not doctor_id:
        return jsonify({'success': False, 'message': 'Doctor not found in appointment'}), 400

    # Update appointment with rating
    mongo.db.appointments.update_one(
        {'_id': ObjectId(appointment_id)},
        {'$set': {'rating': rating}}
    )

    # Push rating to doctor's rating list
    mongo.db.doctors.update_one(
        {'_id': ObjectId(doctor_id)},
        {'$push': {'ratings': rating}}
    )

    return jsonify({'success': True, 'message': 'Rating submitted successfully'}), 200

# change doctor fees
@app.route('/api/doctor/<doctor_id>/fee', methods=['POST'])
def change_fee(doctor_id):
    if not ObjectId.is_valid(doctor_id):
        return jsonify({'success': False, 'message': 'Invalid doctor ID'}), 400

    data = request.get_json()
    fee = data.get('fee')
    if not fee or not isinstance(fee, (int, float)) or not (500 <= fee <= 2500):
        return jsonify({'success': False, 'message': 'Fee must be a number between 500 and 2500'}), 400

    doctor_id = list(mongo.db.users.find({'_id': ObjectId(doctor_id)}))
    if not doctor_id:
        return jsonify({'success': False, 'message': 'Doctor not found in appointment'}), 400

    # Update appointment with rating
    mongo.db.users.update_one(
        {'_id': ObjectId(doctor_id)},
        {'$set': {'fee': fee}}
    )

    return jsonify({'success': True, 'message': 'Fee changed successfully'}), 200





#lab apis
@app.route('/api/lab/tests', methods=['POST'])
def add_lab_test():
    try:
        data = request.get_json()
        if not data:
            return jsonify({'success': False, 'message': 'No data provided'}), 400

        # Validate fields
        lab_user_id = data.get('labUserId')
        test_name = data.get('testName')
        sample_type = data.get('sampleType')
        price = data.get('price')

        if not lab_user_id or not ObjectId.is_valid(lab_user_id):
            return jsonify({'success': False, 'message': 'Invalid or missing lab user ID'}), 400

        if not test_name:
            return jsonify({'success': False, 'message': 'Test name is required'}), 400

        if not sample_type:
            return jsonify({'success': False, 'message': 'Sample type is required'}), 400

        try:
            price = float(price)
        except (ValueError, TypeError):
            return jsonify({'success': False, 'message': 'Price must be a valid number'}), 400

        # Save test
        test = {
            'labUserId': lab_user_id,
            'testName': test_name,
            'sampleType': sample_type,
            'price': price,
            'createdAt': datetime.now(pkt)
        }

        result = mongo.db.tests.insert_one(test)

        return jsonify({
            'success': True,
            'message': 'Test added successfully',
            'testId': str(result.inserted_id)
        }), 201

    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500


@app.route('/api/lab/tests/<lab_user_id>', methods=['GET'])
def get_lab_tests(lab_user_id):
    try:
        if not ObjectId.is_valid(lab_user_id):
            return jsonify({'success': False, 'message': 'Invalid lab user ID'}), 400

        tests = list(mongo.db.tests.find({'labUserId': lab_user_id}))
        for test in tests:
            test['_id'] = str(test['_id'])  # Convert ObjectId to string

        return jsonify({'success': True, 'tests': tests}), 200

    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500




if __name__ == '__main__':
    if not app.debug or os.environ.get('WERKZEUG_RUN_MAIN') == 'true':
        print("[INFO] Starting scheduler...")

    print("[INFO] Starting Flask app...")
    app.run(host='192.168.10.16', port=5000, debug=True)