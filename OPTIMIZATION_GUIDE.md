# Xray Cloud Run - Performance Configuration Guide

## 📊 إعدادات موصى بها حسب حجم المستخدمين

### صغير (10-100 مستخدم)

```bash
Memory: 256MB - 512MB
CPU: 0.5 - 1 core
Timeout: 300s (5 دقائق)
Max Instances: 5-10
Concurrency: 50-100
```

### متوسط (100-1000 مستخدم)

```bash
Memory: 512MB - 1024MB
CPU: 1 - 2 cores
Timeout: 1800s (30 دقيقة)
Max Instances: 10-30
Concurrency: 100-500
```

### كبير (1000+ مستخدم)

```bash
Memory: 2048MB (2GB)
CPU: 2+ cores
Timeout: 3600s (ساعة)
Max Instances: 50-100+
Concurrency: 500-1000+
```

## 🚀 طرق التوزيع

### الطريقة 1: البرنامج التفاعلي الأساسي

```bash
chmod +x install.sh
./install.sh
# سيطلب منك كل الإعدادات تفاعلياً (جميعها اختيارية)
```

### الطريقة 2: البرنامج المرن (موصى به)

```bash
chmod +x deploy-custom.sh
./deploy-custom.sh
# جميع الخيارات اختيارية - اضغط Enter للتخطي
```

### الطريقة 3: عبر متغيرات البيئة

```bash
PROTO=vless WSPATH=/ws SERVICE=my-xray REGION=us-central1 \
MEMORY=1024 CPU=1 TIMEOUT=1800 MAX_INSTANCES=20 CONCURRENCY=500 \
./install.sh
```

### الطريقة 4: أوامر gcloud مباشرة

```bash
gcloud run deploy xray-service \
  --source . \
  --region us-central1 \
  --platform managed \
  --allow-unauthenticated \
  --memory 1024Mi \
  --cpu 1 \
  --timeout 1800 \
  --max-instances 20 \
  --concurrency 500
```

## 📝 شرح كل معامل

| المعامل           | الأمثلة              | الشرح                          |
| ----------------- | -------------------- | ------------------------------ |
| **Memory**        | 256, 512, 1024, 2048 | MB - الذاكرة لكل instance      |
| **CPU**           | 0.5, 1, 2, 4         | عدد المعالجات المخصصة          |
| **Timeout**       | 300, 1800, 3600      | ثواني - مدة انتظار الطلب       |
| **Max Instances** | 5, 10, 20, 50, 100   | الحد الأقصى للـ instances      |
| **Concurrency**   | 50, 100, 500, 1000   | الطلبات المتزامنة لكل instance |

## 💡 نصائح لاختيار الإعدادات

### إذا كنت في البداية:

- ابدأ بـ 256-512 MB
- CPU: 0.5 أو 1
- 5-10 instances
- Monitor الأداء أولاً

### إذا لاحظت بطء:

- زيادة Memory بـ 2x
- أضف المزيد من instances
- زيادة Concurrency

### لـ 1000+ مستخدم:

- استخدم 2048 MB على الأقل
- 2+ CPU cores
- 50+ instances
- 1000+ concurrency

## 📈 الأداء المتوقع

```
50 instances × 500 concurrency = 25,000 concurrent users
100 instances × 1000 concurrency = 100,000 concurrent users
```

Auto-scaling سيزيد عدد instances تلقائياً حسب الطلب.

## 💰 تأثير التكلفة

**أقل تكلفة:**

- 128 MB, 0.5 CPU, 5 instances
- ~$5-10/month

**متوسط:**

- 512 MB, 1 CPU, 20 instances
- ~$20-50/month

**عالي الأداء:**

- 2048 MB, 2 CPU, 100 instances
- ~$100-300/month

_التكاليف تقريبية وتعتمد على الاستخدام الفعلي_

## 🔍 مراقبة الأداء

```bash
# عرض معلومات الخدمة
gcloud run services describe SERVICE_NAME --region REGION

# عرض السجلات
gcloud run services logs read SERVICE_NAME --region REGION

# عرض المقاييس (CPU, Memory)
gcloud run services describe SERVICE_NAME --region REGION --format json
```

## 🎯 التوصيات النهائية

1. **ابدأ صغير** - لا تبدأ بأعلى الإعدادات
2. **اختبر تحت الحمل** - استخدم أداة Load Testing
3. **راقب الأداء** - تابع استخدام الموارد
4. **اضبط تدريجياً** - زيادة الموارد حسب الحاجة
5. **استخدم VLESS** - أسرع وأخف من VMESS

## 📚 المراجع

- [Google Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Cloud Run Pricing Calculator](https://cloud.google.com/run/pricing-calculator)
- [Xray Documentation](https://xtls.github.io)
