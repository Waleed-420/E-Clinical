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
import pytz


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
            'updated_at': datetime.utcnow()
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
    
    doctors = list(mongo.db.doctors.find(query, {
        '_id': 1,
        'name': 1,
        'specialization': 1,
        'schedule': 1
    }))
    
    for doc in doctors:
        doc['_id'] = str(doc['_id'])
    
    return jsonify({'success': True, 'doctors': doctors})

@app.route('/api/doctor/<doctor_id>/specialization/slots', methods=['GET'])
def get_available_slots(doctor_id):
    try:
        # Validate date parameter
        date_str = request.args.get('date')
        if not date_str:
            return jsonify({'success': False, 'message': 'Date parameter is required'}), 400
            
        try:
            date = datetime.strptime(date_str, '%Y-%m-%d')
        except ValueError:
            return jsonify({'success': False, 'message': 'Invalid date format. Use YYYY-MM-DD'}), 400

        # Validate doctor_id
        if not ObjectId.is_valid(doctor_id):
            return jsonify({'success': False, 'message': 'Invalid doctor ID format'}), 400

        # Get doctor's schedule
        doctor = mongo.db.doctors.find_one({'_id': ObjectId(doctor_id)})
        if not doctor:
            return jsonify({'success': False, 'message': 'Doctor not found'}), 404

        # Get booked appointments
        booked_appointments = list(mongo.db.appointments.find({
            'doctorId': doctor_id,
            'date': date_str,
            'status': {'$in': ['booked', 'confirmed']}
        }))

        # Generate available slots
        weekday = str(date.isoweekday())
        schedule = doctor.get('schedule', {}).get(weekday, [])
        available_slots = []
        
        for slot in schedule:
            try:
                start_time = datetime.strptime(slot['start'], '%H:%M').time()
                end_time = datetime.strptime(slot['end'], '%H:%M').time()
                
                current_time = start_time
                while current_time < end_time:
                    slot_str = current_time.strftime('%H:%M')
                    if not any(appt['time'] == slot_str for appt in booked_appointments):
                        available_slots.append({
    'start': slot['start'],
    'end': slot['end'],
    'available': slot_str not in booked_times
})

                    current_time = (datetime.combine(date, current_time) + timedelta(minutes=30)).time()
            except Exception as e:
                app.logger.error(f"Error processing slot: {str(e)}")
                continue

        return jsonify({
            'success': True,
            'slots': available_slots,
            'date': date_str,
            'doctor_id': doctor_id
        })

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
        missing_fields = [field for field in required_fields if field not in data or not data[field]]
        if missing_fields:
            return jsonify({
                'success': False,
                'message': f'Missing required fields: {', '.join(missing_fields)}'
            }), 400

        # Validate doctor
        if not ObjectId.is_valid(data['doctorId']):
            return jsonify({'success': False, 'message': 'Invalid doctor ID format'}), 400

        doctor = mongo.db.doctors.find_one({'_id': ObjectId(data['doctorId'])})
        if not doctor:
            return jsonify({'success': False, 'message': 'Doctor not found'}), 404

        # Validate date
        try:
            datetime.strptime(data['date'], '%Y-%m-%d')
        except ValueError:
            return jsonify({'success': False, 'message': 'Invalid date format. Use YYYY-MM-DD'}), 400

        # Check if slot is already booked
        already_booked = mongo.db.appointments.find_one({
            'doctorId': data['doctorId'],
            'date': data['date'],
            'time': data['time'],
            'status': {'$in': ['booked', 'confirmed']}
        })
        if already_booked:
            return jsonify({'success': False, 'message': 'This time slot is already booked'}), 400

        # Create appointment
        appointment = {
            'userId': data['userId'],
            'doctorId': data['doctorId'],
            'doctorName': doctor.get('name'),
            'date': data['date'],
            'time': data['time'],
            'payment': data.get('payment', None),  # Optional
            'status': 'booked',
            'created_at': datetime.utcnow(),
            'updated_at': datetime.utcnow()
        }

        result = mongo.db.appointments.insert_one(appointment)
        appointment['_id'] = str(result.inserted_id)

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
            'updated_at': datetime.utcnow()
        }}
    )

    # Also ensure it's updated in doctors collection if exists
    mongo.db.doctors.update_one(
        {'_id': ObjectId(doctor_id)},
        {'$set': {
            'specialization': specialization,
            'updated_at': datetime.utcnow()
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
    if role == 'General User':
        appointments = list(mongo.db.appointments.find({'userId': user_id}))
        for appt in appointments:
            doctor = mongo.db.doctors.find_one({'_id': ObjectId(appt['doctorId'])})
            appt['otherName'] = doctor.get('name') if doctor else 'Unknown Doctor'
    elif role == 'Doctor':
        appointments = list(mongo.db.appointments.find({'doctorId': user_id}))
        for appt in appointments:
            patient = mongo.db.users.find_one({'_id': ObjectId(appt['userId'])})
            appt['otherName'] = patient.get('name') if patient else 'Unknown Patient'
    else:
        appointments = []

    for appt in appointments:
        appt['_id'] = str(appt['_id'])

    return jsonify({'success': True, 'appointments': appointments}), 200

from apscheduler.schedulers.background import BackgroundScheduler
from datetime import datetime, timedelta
import pytz

def check_upcoming_appointments():
    now = datetime.utcnow().replace(tzinfo=pytz.utc)
    five_mins_later = now + timedelta(minutes=24)
    today_str = now.strftime('%Y-%m-%d')

    upcoming = mongo.db.appointments.find({
        'date': today_str,
        'status': {'$in': ['booked', 'confirmed']}
    })

    for appt in upcoming:
        appt_time = datetime.strptime(f"{appt['date']} {appt['time']}", "%Y-%m-%d %H:%M")
        appt_time = appt_time.replace(tzinfo=pytz.utc)

        if now <= appt_time <= five_mins_later:
            send_notification(appt)

def send_notification(appt):
    user = mongo.db.users.find_one({'_id': ObjectId(appt['userId'])})
    doctor = mongo.db.doctors.find_one({'_id': ObjectId(appt['doctorId'])})
    
    user_msg = f"Reminder: Your appointment with Dr. {doctor.get('name')} is at {appt['time']}."
    doctor_msg = f"Reminder: You have an appointment with {user.get('name')} at {appt['time']}."

    # Replace with actual push/email/sms service
    print("Notify User:", user_msg)
    print("Notify Doctor:", doctor_msg)

scheduler = BackgroundScheduler()
scheduler.add_job(check_upcoming_appointments, 'interval', minutes=1)
scheduler.start()





if __name__ == '__main__':
    app.run(
        host='192.168.1.4',
        port=5000,
        debug=True
    )
