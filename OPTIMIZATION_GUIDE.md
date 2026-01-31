# Xray Cloud Run - 1000+ Users Performance Optimization

## مقارنة الإعدادات

### للمستخدمين العاديين (10-100 مستخدم)

```bash
Memory: 256MB - 512MB
CPU: 0.5 - 1 core
Timeout: 300s (5 دقائق)
Max Instances: 10-20
```

### للأداء العالي (1000+ مستخدم)

```bash
Memory: 2048MB (2GB)      ✅ 4x زيادة الذاكرة
CPU: 2 cores             ✅ 2x زيادة المعالج
Timeout: 3600s (ساعة)    ✅ 12x زيادة المدة
Max Instances: 100       ✅ 5-10x زيادة الحد الأقصى
Max Concurrency: 1000    ✅ 1000 طلب متزامن لكل instance
```

## الاستخدام

### الطريقة السريعة (محسّنة تلقائياً):

```bash
chmod +x deploy-1000-users.sh
./deploy-1000-users.sh
```

### باستخدام البرنامج الأصلي مع المعاملات المخصصة:

```bash
MEMORY=2048 CPU=2 TIMEOUT=3600 MAX_INSTANCES=100 ./install.sh
```

### باستخدام gcloud مباشرة:

```bash
gcloud run deploy xray-service \
  --region us-central1 \
  --memory 2048Mi \
  --cpu 2 \
  --timeout 3600 \
  --max-instances 100 \
  --concurrency 1000 \
  --allow-unauthenticated
```

## شرح المعاملات

| المعامل           | القيمة  | الشرح                                                                   |
| ----------------- | ------- | ----------------------------------------------------------------------- |
| **Memory**        | 2048MB  | الذاكرة المخصصة لكل instance - زيادة تحسن الأداء مع المستخدمين الكثيرين |
| **CPU**           | 2 cores | معالجات - أساسية لمعالجة الاتصالات المتزامنة                            |
| **Timeout**       | 3600s   | مدة انتظار الطلب - مهم لـ WebSocket طويلة المدى                         |
| **Max Instances** | 100     | الحد الأقصى للـ instances - يسمح بـ auto-scaling                        |
| **Concurrency**   | 1000    | الطلبات المتزامنة لكل instance                                          |

## الأداء المتوقع

مع هذه الإعدادات:

- **100 instances × 1000 requests/instance = 100,000+ concurrent connections**
- كل instance يستطيع معالجة 1000 اتصال متزامن
- Google Cloud Run سيقوم بـ auto-scaling تلقائياً

## التكلفة

ستكون أعلى من الإعدادات الصغيرة:

- 2048MB + 2 CPU = تكلفة أعلى
- Auto-scaling يعني دفع مقابل الموارد المستخدمة فقط
- لا توجد تكاليف ثابتة

## خطوات التوزيع

1. **إعداد gcloud**

```bash
gcloud init
gcloud config set project YOUR_PROJECT_ID
```

2. **تشغيل السكريبت المحسّن**

```bash
./deploy-1000-users.sh
```

3. **اختبار الأداء**

```bash
curl -v https://your-service.run.app/ws
```

4. **مراقبة الأداء**

```bash
gcloud run services describe xray-optimized --region us-central1
```

## نصائح التحسين الإضافية

- استخدم **VLESS** بدلاً من VMESS (أسرع وأخف)
- فعّل **connection reuse** في WebSocket
- استخدم **geolocation routing** لتحسين الأداء
- قم بمراقبة CPU و Memory استخدام دوراً
- زد عدد instances إذا لاحظت تأخير

## المراجع

- [Google Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Xray Documentation](https://xtls.github.io)
- [Cloud Run Pricing](https://cloud.google.com/run/pricing)
