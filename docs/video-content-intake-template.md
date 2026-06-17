# Video Content Intake Template

Use this template when sending video links for CMS entry.

Hosting plan
- `Cloudinary`: `educational`, `behavioral`
- `Google Drive`: `skillful`, `entertaining`

Required fields per video
- `title_en`
- `title_ar`
- `category_slug`
- `content_type`: usually `video`
- `description_en`
- `description_ar`
- `thumbnail_url`
- `video_url`

Optional fields
- `video_preview_url`
- `video_provider`: `cloudinary` or `google_drive`
- `video_host_tier`: `fast-cloud` or `budget-drive`
- `age_group`
- `tags`
- `duration_minutes`

Recommended category mapping
- `educational` -> `cloudinary` + `fast-cloud`
- `behavioral` -> `cloudinary` + `fast-cloud`
- `skillful` -> `google_drive` + `budget-drive`
- `entertaining` -> `google_drive` + `budget-drive`

One-item template

```json
{
  "title_en": "",
  "title_ar": "",
  "category_slug": "",
  "content_type": "video",
  "description_en": "",
  "description_ar": "",
  "thumbnail_url": "",
  "video_url": "",
  "video_preview_url": "",
  "video_provider": "",
  "video_host_tier": "",
  "age_group": "5-7",
  "tags": []
}
```

Cloudinary example

```json
{
  "title_en": "Numbers Song",
  "title_ar": "أغنية الأرقام",
  "category_slug": "educational",
  "content_type": "video",
  "description_en": "A quick counting song for kids.",
  "description_ar": "أغنية سريعة لتعليم العد للأطفال.",
  "thumbnail_url": "https://res.cloudinary.com/demo/image/upload/v1/numbers-thumb.jpg",
  "video_url": "https://res.cloudinary.com/demo/video/upload/v1/numbers-song.mp4",
  "video_preview_url": "https://res.cloudinary.com/demo/video/upload/f_auto,q_auto/v1/numbers-song.mp4",
  "video_provider": "cloudinary",
  "video_host_tier": "fast-cloud",
  "age_group": "4-6",
  "tags": ["numbers", "song"]
}
```

Google Drive example

```json
{
  "title_en": "Funny Animal Time",
  "title_ar": "وقت الحيوانات المضحكة",
  "category_slug": "entertaining",
  "content_type": "video",
  "description_en": "A light and fun clip for play time.",
  "description_ar": "مقطع خفيف وممتع لوقت اللعب.",
  "thumbnail_url": "https://drive.google.com/thumbnail?id=FILE_ID",
  "video_url": "https://drive.google.com/file/d/FILE_ID/view?usp=sharing",
  "video_preview_url": "https://drive.google.com/file/d/FILE_ID/preview",
  "video_provider": "google_drive",
  "video_host_tier": "budget-drive",
  "age_group": "5-7",
  "tags": ["fun", "animals"]
}
```
