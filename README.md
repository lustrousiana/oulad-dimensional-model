# oulad-dimensional-model

## Overview

This project transforms the Instacart dataset into a dimensional model designed for analytics and reporting.

The pipeline follows a Medallion Architecture:

```text
Source (Cloudflare R2, CSV)
   ↓
Raw/Bronze
   ↓
Clean/Silver
   ↓
Mart/Gold
   ↓
Dimensional Model
```
