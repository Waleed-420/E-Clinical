from pymongo import MongoClient
from datetime import datetime

# Connect to MongoDB
client = MongoClient('mongodb://localhost:27017/')
db = client['healthcare_app']

# Drop the chats collection if it exists
db.chats.drop()

# Remove any TTL indexes related to chats
for index in db.chats.list_indexes():
    if 'expireAfterSeconds' in index:
        db.chats.drop_index(index['name'])

print("Chat-related data and indexes have been removed successfully")
