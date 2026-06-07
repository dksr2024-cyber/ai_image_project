from fastapi import FastAPI, UploadFile, File, Form, HTTPException, Depends
from fastapi.responses import FileResponse
from rembg import remove
from PIL import Image
import io, os, uuid
from database import SessionLocal, User

# ១. បង្កើតថតសម្រាប់ផ្ទុករូបភាពបណ្តោះអាសន្ន
TEMP_DIR = "temp_images"
os.makedirs(TEMP_DIR, exist_ok=True)

# ២. ចាប់ផ្តើម FastAPI App
app = FastAPI()

def get_db():
    db = SessionLocal()
    try: 
        yield db
    finally: 
        db.close()

# ៣. មុខងារស្វាគមន៍សម្រាប់ទំព័រដើម
@app.get("/")
async def root():
    return {"message": "សូមស្វាគមន៍មកកាន់ AI Image Pro API Server!", "status": "Running Smoothly"}

# ៤. មុខងារដំណើរការរូបភាព (គ្មាន Firebase Auth)
@app.post("/process/")
async def process_image(
    action: str = Form(...),
    file: UploadFile = File(...),
    db = Depends(get_db)
):
    # បង្កើត User ក្លែងក្លាយមួយឈ្មោះ "test_user_123" សម្រាប់តែការតេស្តប៉ុណ្ណោះ
    uid = "test_user_123"
    user = db.query(User).filter(User.id == uid).first()
    
    if not user:
        user = User(id=uid, credits=100) # ផ្តល់ 100 credits ឲ្យ User តេស្ត
        db.add(user)
        db.commit()
        db.refresh(user)

    if user.credits < 10:
        raise HTTPException(status_code=402, detail="អស់ Credits!")

    try:
        # អានទិន្នន័យរូបភាព
        img_data = await file.read()
        img = Image.open(io.BytesIO(img_data)).convert("RGBA")

        # ដំណើរការមុខងារតាមការស្នើសុំ
        if action == "bg_remove":
            img = remove(img)
        elif action == "upscale_4k":
            # Resize ធម្មតាសិន សម្រាប់ Upscale 4K បណ្តោះអាសន្ន
            img = img.resize((3840, int(3840 * img.height / img.width)), Image.LANCZOS)
        
        # កាត់ Credits (កាត់ 10 Credits ពេលដំណើរការម្តង)
        user.credits -= 10
        db.commit()
        
        # រក្សាទុក និងបញ្ជូនរូបភាពត្រឡប់ទៅវិញ
        path = os.path.join(TEMP_DIR, f"{uuid.uuid4()}.png")
        img.save(path, "PNG")
        
        return FileResponse(path)
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
