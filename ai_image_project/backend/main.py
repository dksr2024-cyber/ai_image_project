from fastapi import FastAPI, UploadFile, File, Form, HTTPException, Depends, Security
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.responses import FileResponse
from apscheduler.schedulers.background import BackgroundScheduler
from rembg import remove
from PIL import Image
import firebase_admin
from firebase_admin import credentials, auth
import io, os, uuid, time
from database import SessionLocal, User

# ១. ការកំណត់ Firebase (Security)
# នៅលើ Render ត្រូវប្រាកដថាអ្នកបានដាក់ឯកសារ firebase-key.json ឬប្រើប្រាស់ Environment Variables
cred = credentials.Certificate("firebase-key.json") 
firebase_admin.initialize_app(cred)
security = HTTPBearer()

def verify_token(credentials: HTTPAuthorizationCredentials = Security(security)):
    try:
        decoded_token = auth.verify_id_token(credentials.credentials)
        return decoded_token['uid'] # ត្រឡប់ User ID ដែលបានពី Firebase
    except Exception as e:
        raise HTTPException(status_code=401, detail="គ្មានសិទ្ធិអនុញ្ញាត ឬ Token ផុតកំណត់")

# ២. ការកំណត់ Storage Cleanup (Cron Job)
TEMP_DIR = "temp_images"
os.makedirs(TEMP_DIR, exist_ok=True)

def cleanup_old_images():
    """លុបរូបភាពណាដែលមានអាយុកាលលើសពី ២៤ ម៉ោង"""
    now = time.time()
    for filename in os.listdir(TEMP_DIR):
        file_path = os.path.join(TEMP_DIR, filename)
        if os.path.isfile(file_path):
            # បើ File ទុកចោលលើសពី 86400 វិនាទី (២៤ម៉ោង)
            if os.stat(file_path).st_mtime < now - 86400:
                os.remove(file_path)
                print(f"បានលុប file ចាស់: {filename}")

scheduler = BackgroundScheduler()
scheduler.add_job(cleanup_old_images, 'interval', hours=24)
scheduler.start()

# ៣. ចាប់ផ្តើម FastAPI App
app = FastAPI()

def get_db():
    db = SessionLocal()
    try: yield db
    finally: db.close()

# ៤. ដំណើរការ AI (មានភ្ជាប់ Firebase Auth)
@app.post("/process/")
async def process_image(
    action: str = Form(...),
    file: UploadFile = File(...),
    uid: str = Depends(verify_token), # តម្រូវឲ្យមាន Token ពី App
    db = Depends(get_db)
):
    user = db.query(User).filter(User.id == uid).first()
    if not user or user.credits < 10:
        raise HTTPException(status_code=402, detail="អស់ Credits!")

    img_data = await file.read()
    img = Image.open(io.BytesIO(img_data)).convert("RGBA")

    if action == "bg_remove":
        img = remove(img)
    elif action == "upscale_4k":
        # កន្លែងនេះដាក់ AI Model ពិតប្រាកដរបស់អ្នក
        img = img.resize((3840, int(3840 * img.height / img.width)), Image.LANCZOS)
    
    # កាត់ Credits រួច Save
    user.credits -= 10
    db.commit()
    
    path = os.path.join(TEMP_DIR, f"{uuid.uuid4()}.png")
    img.save(path, "PNG")
    return FileResponse(path)

# ៥. Webhook សម្រាប់ ABA PayWay
@app.post("/aba-webhook/")
async def aba_webhook(req_data: dict, db = Depends(get_db)):
    """
    ABA នឹងបាញ់ទិន្នន័យមកទីនេះពេលអតិថិជនបង់លុយរួច
    អ្នកត្រូវផ្ទៀងផ្ទាត់ Hash ជាមួយ Secret Key របស់អ្នកមុននឹងបន្ថែម Credit
    """
    # ឧទាហរណ៍: req_data មាន status, user_id, amount
    if req_data.get("status") == "APPROVED":
        uid = req_data.get("user_id")
        user = db.query(User).filter(User.id == uid).first()
        if user:
            user.credits += int(req_data.get("amount", 0)) * 10 # $1 = 10 credits
            db.commit()
            return {"message": "ជោគជ័យ"}
    return {"message": "បរាជ័យ"}