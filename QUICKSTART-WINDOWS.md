# Quick Start - Windows

> Dùng hệ điều hành khác? Xem [`QUICKSTART-MAC.md`](QUICKSTART-MAC.md) (macOS) hoặc [`QUICKSTART-LINUX.md`](QUICKSTART-LINUX.md) (Linux).

## Yêu cầu trước khi bắt đầu

| Thứ cần chuẩn bị | Chi tiết | Bắt buộc? |
|-------------------|----------|-----------|
| **Windows 10/11** (Pro/Enterprise/Home đều được) | WSL2 yêu cầu Windows 10 version 1903+ hoặc Windows 11 | **Bắt buộc** |
| **Docker Desktop** | Cài từ https://docs.docker.com/desktop/setup/install/windows-install/ → chọn "Use WSL 2" trong quá trình cài | **Bắt buộc** |
| **Tài khoản Kaggle** | Đăng ký miễn phí tại https://www.kaggle.com để chạy notebook | **Bắt buộc** |
| Python local | **Không cần** — tất cả services chạy trong Docker, notebook chạy trên Kaggle/Colab | Không cần |
| Python packages local | **Không cần** — notebook tự cài `requests`, `pandas`, `matplotlib`, `plotly`, `torch`, `torchvision`, `pynvml` trên Kaggle/Colab | Không cần |

> **Lưu ý:** `cloudflared` (tunnel) **miễn phí, không cần đăng ký tài khoản**.

## Cách nhanh nhất: chạy trực tiếp bằng PowerShell

Nếu Docker Desktop đã chạy, có thể dùng script native Windows ngay trong thư mục project:

```powershell
cd D:\Day24\Day25-Lab-GPU-FinOps-Cost_Optimization
powershell -ExecutionPolicy Bypass -File .\run-windows.ps1 start
powershell -ExecutionPolicy Bypass -File .\run-windows.ps1 test
```

Mở tunnel để Kaggle/Colab truy cập gateway:

```powershell
powershell -ExecutionPolicy Bypass -File .\run-windows.ps1 tunnel
```

Script sẽ in ra URL dạng `https://...trycloudflare.com`; copy URL đó vào notebook:

```python
GATEWAY_URL = "https://...trycloudflare.com"
```

Các lệnh PowerShell hữu ích:

| Lệnh | Mô tả |
|-------|------|
| `powershell -ExecutionPolicy Bypass -File .\run-windows.ps1 start` | Build và chạy toàn bộ Docker services |
| `powershell -ExecutionPolicy Bypass -File .\run-windows.ps1 tunnel` | Mở tunnel qua `cloudflared` hoặc `ngrok` |
| `powershell -ExecutionPolicy Bypass -File .\run-windows.ps1 test` | Test nhanh các endpoint chính |
| `powershell -ExecutionPolicy Bypass -File .\run-windows.ps1 status` | Xem trạng thái services và tunnel |
| `powershell -ExecutionPolicy Bypass -File .\run-windows.ps1 logs gateway` | Xem log service gateway |
| `powershell -ExecutionPolicy Bypass -File .\run-windows.ps1 stop` | Tắt services và tunnel |

Nếu chưa có tunnel tool, cài một trong hai:

```powershell
winget install --id Cloudflare.cloudflared
# hoặc
winget install --id Ngrok.Ngrok
```

---

## Cách thay thế: chạy trong WSL2

## Tổng quan các bước

```
WSL Terminal 1: Docker services    WSL Terminal 2: Tunnel    Browser: Kaggle notebook
     │                                  │                        │
     ▼                                  ▼                        ▼
./run-linux.sh start             ./run-linux.sh tunnel      Paste URL → Run cells
```

> Sau khi cài WSL2 + Ubuntu, mọi bước chạy **giống hệt Linux**.

---

## Bước 0: Cài WSL2 + Ubuntu + Docker Desktop (1 lần duy nhất)

### 1. Bật WSL2

Mở **PowerShell với quyền Administrator** (Run as Administrator) và chạy:

```powershell
wsl --install -d Ubuntu
```

> Nếu đã cài WSL trước đó, cập nhật lên WSL2:
> ```powershell
> wsl --set-default-version 2
> ```

Khởi động lại máy khi được yêu cầu. Sau đó Ubuntu sẽ tự động cài đặt.

---

### 2. Cài Docker Desktop với WSL backend

1. Tải Docker Desktop: https://docs.docker.com/desktop/setup/install/windows-install/
2. Cài đặt → chọn **"Use WSL 2 instead of Hyper-V"**
3. Khởi động Docker Desktop
4. Vào **Settings → Resources → WSL integration**
5. Bật **"Enable integration with my default WSL distro"** và **bật Ubuntu**
6. Nhấn **Apply & Restart**

---

### 3. Kiểm tra Docker trong WSL

Mở **Ubuntu terminal** (từ Start Menu hoặc `wsl` trong PowerShell):

```bash
docker --version
docker compose version
```

Nếu hiện version → Docker đã sẵn sàng.

---

## Bước 1: Copy project vào WSL filesystem

> **Lưu ý quan trọng**: Chạy project từ **bên trong WSL filesystem** (`~/...`) sẽ nhanh hơn nhiều so với chạy từ ổ C (`/mnt/c/...`).

Mở **Ubuntu terminal** và chạy:

```bash
# Copy project từ Windows vào WSL home
cp -r "/mnt/c/Users/$USER/Day 25-Track02-/gpu-finops-lab" ~/gpu-finops-lab
# hoặc nếu project ở Desktop:
cp -r "/mnt/c/Users/$USER/Desktop/Day 25-Track02-/gpu-finops-lab" ~/gpu-finops-lab

cd ~/gpu-finops-lab
```

> Xác định đúng đường dẫn Windows: mở File Explorer → tìm folder `Day 25-Track02-` → copy đường dẫn.
> Trong WSL, đường dẫn Windows `C:\Users\<name>\...` tương ứng `/mnt/c/Users/<name>/...`.

---

## Bước 2: Cài tunnel tool (1 lần duy nhất)

Trong **Ubuntu terminal** (WSL):

```bash
cd ~/gpu-finops-lab

# Cài cloudflared
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o /tmp/cloudflared.deb
sudo dpkg -i /tmp/cloudflared.deb
```

> Miễn phí, không cần đăng ký tài khoản.

---

## Bước 3: Start Docker services

Trong **Ubuntu terminal** (WSL):

```bash
cd ~/gpu-finops-lab
./run-linux.sh start
```

Kết quả mong đợi:
```
[STEP] 1/3 - Checking Docker...
  Docker is running
[STEP] 2/3 - Building and starting services...
[STEP] 3/3 - Waiting for services to be healthy...
  Gateway is UP at http://localhost:8000

==========================================
 ALL SERVICES RUNNING
==========================================
```

> Lần đầu build sẽ mất ~2-3 phút. Lần sau chỉ ~5 giây.

---

## Bước 4: Mở tunnel

Trong **cùng terminal** hoặc mở **terminal Ubuntu mới** (WSL):

```bash
cd ~/gpu-finops-lab
./run-linux.sh tunnel
```

Kết quả thực tế (log mẫu):
```
./run-linux.sh tunnel

[STEP] Starting tunnel to expose gateway...
[INFO] Using cloudflared (free, no account needed)
  Starting tunnel...
2026-05-12T15:58:22Z INF Thank you for trying Cloudflare Tunnel. Doing so, without a Cloudflare account,
  is a quick way to experiment and try it out. However, be aware that these account-less Tunnels have
  no uptime guarantee...
2026-05-12T15:58:22Z INF Requesting new quick Tunnel on trycloudflare.com...

2026-05-12T15:58:25Z INF +--------------------------------------------------------------------------------------------+
2026-05-12T15:58:25Z INF |  Your quick Tunnel has been created! Visit it at (it may take some time to be reachable):  |
2026-05-12T15:58:25Z INF |  https://<your-random-subdomain>.trycloudflare.com                            |
2026-05-12T15:58:25Z INF +--------------------------------------------------------------------------------------------+

2026-05-12T15:58:25Z INF Version 2026.3.0
2026-05-12T15:58:25Z INF GOOS: linux, GOVersion: go1.26.1, GoArch: amd64
2026-05-12T15:58:25Z INF Settings: map[ha-connections:1 protocol:quic url:http://localhost:8000]
2026-05-12T15:58:35Z INF Initial protocol quic
2026-05-12T15:58:45Z INF Registered tunnel connection connIndex=0 location=hkg01 protocol=quic
```

> **URL nằm ở dòng có `trycloudflare.com`** — copy URL đó paste vào notebook.
>
> Các dòng `ERR Failed to refresh DNS` ở cuối là bình thường, **không ảnh hưởng** tunnel.

Nếu script hiện URL thành công:
```
==========================================
 TUNNEL ACTIVE
==========================================

  URL: https://<your-random-subdomain>.trycloudflare.com

  Copy this URL into your Kaggle/Colab notebook:
  GATEWAY_URL = "https://<your-random-subdomain>.trycloudflare.com"
```

---

## Bước 5: Test nhanh (optional)

```bash
./run-linux.sh test
```

```
  [OK] GET /
  [OK] GET /cluster/nodes
  [OK] GET /cluster/metrics
  [OK] GET /billing/pricing
  [OK] GET /spot/pricing
  [OK] GET /autoscaler/policy
  [OK] GET /cost/dashboard
```

---

## Bước 6: Upload & chạy notebook trên Kaggle

1. Vào https://www.kaggle.com → **New Notebook**
2. Upload file `notebook/gpu_finops_lab.ipynb`
3. Settings → **Accelerator** → **GPU T4 x2** (hoặc P100)
4. Trong **Cell 2**, thay URL:
   ```python
   GATEWAY_URL = "https://abc-xyz-123.trycloudflare.com"  # URL từ bước 4
   ```
5. **Run All Cells**

---

## Các lệnh hữu ích

| Lệnh | Mô tả |
|-------|--------|
| `./run-linux.sh start` | Khởi động tất cả services |
| `./run-linux.sh tunnel` | Mở tunnel cho Kaggle/Colab |
| `./run-linux.sh stop` | Tắt tất cả |
| `./run-linux.sh status` | Xem trạng thái |
| `./run-linux.sh logs` | Xem logs (tất cả services) |
| `./run-linux.sh logs gateway` | Xem logs gateway thôi |
| `./run-linux.sh test` | Test tất cả endpoints |

---

## Troubleshooting

### Docker Desktop không chạy
1. Mở Docker Desktop từ Start Menu
2. Đợi 10-20s rồi chạy lại `./run-linux.sh start`
3. Kiểm tra WSL integration đã bật trong Docker Settings

### WSL không có quyền chạy Docker
```bash
# Thêm user vào docker group
sudo usermod -aG docker $USER
# Đóng và mở lại terminal WSL
```

### Port đã bị chiếm
```bash
# Trong WSL, xem ai đang dùng port 8000
sudo ss -tlnp | grep :8000
# Kill process đó
sudo kill -9 <PID>
```

### Tunnel không hiện URL
```bash
# Xem log trực tiếp
cat .tunnel.log
# Hoặc chạy thủ công
cloudflared tunnel --url http://localhost:8000
```

### Kaggle/Colab không connect được
- Kiểm tra tunnel còn chạy: `./run-linux.sh status`
- Cloudflared URL thay đổi mỗi lần chạy → phải copy URL mới
- Nếu dùng ngrok free, chỉ 1 tunnel tại 1 thời điểm

### Copy project từ Windows sang WSL bị lỗi path
- Tránh dấu cách trong path nếu có thể
- Dùng dấu nháy kép: `cp -r "/mnt/c/..." ~/`
- Hoặc dùng `wslpath` để convert path: `wslpath "C:\Users\..."`

### Rebuild sau khi sửa code
```bash
./run-linux.sh stop
./run-linux.sh start    # tự rebuild
```

---

## Cấu trúc project

```
gpu-finops-lab/
├── run-linux.sh                ← Script điều khiển chính (dùng trong WSL)
├── docker-compose.yml          ← Orchestrate services
├── QUICKSTART-WINDOWS.md     ← File này
├── README.md                   ← Tài liệu đầy đủ
├── notebook/
│   └── gpu_finops_lab.ipynb    ← Upload lên Kaggle/Colab
└── services/
    ├── gateway/                ← API Gateway (port 8000)
    ├── gpu-node-manager/       ← Mock GPU cluster (port 8001)
    ├── billing-api/            ← Mock billing (port 8002)
    ├── spot-manager/           ← Spot instances (port 8003)
    ├── autoscaler/             ← KEDA-like (port 8004)
    └── cost-tracker/           ← OpenCost-like (port 8005)
```
