# Báo cáo GPU FinOps & Cost Optimization Hands-on Lab

## Thông tin sinh viên

- Họ và tên: `Nguyễn Hữu Huy`
- MSSV: `2A202600166`
- Môi trường local: Windows + Docker Desktop
- Môi trường GPU: Kaggle/Colab GPU
- Notebook: `notebook/gpu_finops_lab.ipynb`

## 1. Giới thiệu

Bài lab GPU FinOps & Cost Optimization mô phỏng một hệ thống quản trị chi phí GPU gồm các service chạy local bằng Docker Compose và một notebook chạy trên Kaggle/Colab để tương tác với hệ thống qua tunnel. Mục tiêu chính là thực hành các kỹ năng FinOps cho workload AI/ML: theo dõi tài nguyên GPU, ghi nhận chi phí, dùng spot instance, autoscaling, phát hiện lãng phí, trực quan hóa chi phí và tối ưu hóa workload GPU thực tế.

GPU FinOps là phương pháp kết hợp giữa kỹ thuật vận hành hạ tầng GPU và quản trị tài chính cloud. Trong các dự án AI/ML, GPU thường là phần chi phí lớn nhất. Vì vậy, việc đo lường utilization, memory usage, power draw, runtime, loại GPU và mô hình giá là điều kiện bắt buộc để ra quyết định tối ưu chi phí mà vẫn đảm bảo hiệu năng và deadline.

## 2. Kiến trúc hệ thống

Lab sử dụng mô hình local gateway kết nối notebook từ xa:

- `gateway` chạy tại port `8000`, là điểm truy cập duy nhất cho notebook.
- `gpu-node-manager` chạy tại port `8001`, mô phỏng cụm GPU nhiều node.
- `billing-api` chạy tại port `8002`, mô phỏng ghi nhận và tổng hợp chi phí.
- `spot-manager` chạy tại port `8003`, mô phỏng giá spot, bid và preemption.
- `autoscaler` chạy tại port `8004`, mô phỏng cơ chế scale theo utilization.
- `cost-tracker` chạy tại port `8005`, mô phỏng cost allocation, waste report và recommendation.

Trên Windows, các service được chạy bằng Docker Desktop. Notebook trên Kaggle/Colab truy cập local gateway thông qua URL tunnel từ `cloudflared` hoặc `ngrok`.

## 3. Phân tích từng phần

### Part 1: GPU Cluster Monitoring

Phần đầu tiên tập trung vào việc quan sát trạng thái GPU cluster. Notebook gọi API `/cluster/nodes` để hiển thị danh sách node và GPU, bao gồm loại GPU, utilization, memory used, memory total, power draw, temperature và trạng thái idle/running.

API `/cluster/metrics` tổng hợp các chỉ số quan trọng như tổng số GPU, số GPU bận, số GPU idle, utilization trung bình, tổng memory usage và tổng power draw. Các chỉ số này cho thấy mức độ sử dụng tài nguyên thực tế của cụm. Nếu nhiều GPU ở trạng thái idle nhưng vẫn tiêu thụ chi phí, đây là tín hiệu cần scale down hoặc gom workload để giảm waste.

Nhận xét: monitoring là bước nền tảng của GPU FinOps. Không thể tối ưu chi phí nếu không biết GPU nào đang chạy, GPU nào đang rảnh và workload nào đang sử dụng tài nguyên.

### Part 2: Workload Submission & Cost Tracking

Phần này submit nhiều workload vào mock GPU cluster qua endpoint `/cluster/workloads/submit`. Mỗi workload có thông tin như workload ID, loại GPU ưu tiên, số GPU cần dùng và thời lượng chạy. Sau khi workload được gán GPU, trạng thái GPU chuyển từ `idle` sang `running`, utilization và memory usage tăng lên.

Sau đó notebook ghi nhận billing event qua endpoint `/billing/record`. Chi phí được tính theo công thức:

```text
cost = gpu_price_per_hour × duration_hours × gpu_count
```

Nếu workload dùng spot instance, chi phí được áp dụng discount và phần chênh lệch được ghi nhận là savings.

Nhận xét: chi phí GPU phụ thuộc trực tiếp vào loại GPU, số lượng GPU và thời gian chạy. A100 có chi phí cao hơn T4/V100, vì vậy cần chọn GPU theo yêu cầu workload thay vì mặc định dùng GPU mạnh nhất.

### Part 3: Spot Instance Management

Phần spot instance mô phỏng việc lấy giá spot hiện tại, gửi spot request và kiểm tra rủi ro preemption. Spot instance có giá thấp hơn on-demand, thường tiết kiệm khoảng 60-70%, nhưng có thể bị thu hồi khi cloud provider cần tài nguyên.

Endpoint `/spot/pricing` trả về giá on-demand, giá spot hiện tại, mức discount và availability. Endpoint `/spot/request` kiểm tra bid price của người dùng; nếu bid thấp hơn giá spot hiện tại thì request bị từ chối, ngược lại instance được cấp phát. Endpoint `/spot/simulate-preemption` mô phỏng preemption và `/spot/savings-report` tổng hợp savings.

Nhận xét: spot instance phù hợp với workload có khả năng retry/checkpoint, ví dụ training có checkpoint định kỳ, batch job hoặc experiment không yêu cầu uptime tuyệt đối. Với workload production hoặc deadline nghiêm ngặt, cần giới hạn tỷ lệ spot hoặc kết hợp on-demand để giảm rủi ro.

### Part 4: Autoscaling

Autoscaler sử dụng policy gồm `scale_up_threshold`, `scale_down_threshold`, `cooldown_seconds`, `max_nodes`, `min_nodes`, `preferred_gpu_type` và `cost_aware`. Khi utilization trung bình vượt ngưỡng scale up, autoscaler thêm node mới. Khi utilization thấp hơn ngưỡng scale down, autoscaler khuyến nghị giảm node để tránh over-provisioning.

Trong lab, endpoint `/autoscaler/policy` dùng để xem và cập nhật policy, còn `/autoscaler/evaluate` dùng để trigger đánh giá scaling. Cooldown giúp tránh scale liên tục khi workload dao động ngắn hạn.

Nhận xét: autoscaling giúp cân bằng giữa hiệu năng và chi phí. Scale up đảm bảo workload không bị thiếu tài nguyên, còn scale down giảm chi phí idle GPU. Policy cần được cấu hình thận trọng để tránh vừa over-provisioning vừa tránh queue workload quá lâu.

### Part 5: Cost Analysis & Optimization

Cost tracker tạo các snapshot chi phí theo thời gian qua endpoint `/cost/snapshot`. Mỗi snapshot ghi nhận cost theo node, idle cost, active cost, total cost và waste percentage. Waste percentage cao cho thấy nhiều GPU đang idle nhưng vẫn phát sinh chi phí.

Endpoint `/cost/waste-report` tổng hợp waste trong các snapshot gần nhất và ước tính potential monthly savings. Endpoint `/cost/recommendations` sinh recommendation như right-size GPU, scale down idle resource, dùng spot instance cho workload fault-tolerant và scheduling workload vào thời điểm chi phí thấp.

Nhận xét: đây là phần quan trọng nhất về FinOps vì nó chuyển dữ liệu kỹ thuật thành quyết định tài chính. Thay vì chỉ nhìn utilization, cost tracker cho biết lãng phí đang tương ứng bao nhiêu USD và nên ưu tiên hành động nào.

### Part 6: Visualization

Phần visualization tạo các biểu đồ như `finops_cost_breakdown.png` và `finops_timeseries.png`. Cost breakdown giúp so sánh chi phí giữa GPU type, spot savings và budget utilization. Time-series chart giúp quan sát xu hướng chi phí, active cost, idle cost và waste percentage theo thời gian.

Nhận xét: biểu đồ giúp trình bày kết quả FinOps rõ ràng hơn cho cả nhóm kỹ thuật và nhóm quản lý. Các biểu đồ này đặc biệt hữu ích khi cần báo cáo cost trend, waste trend và hiệu quả tối ưu sau khi áp dụng recommendation.

### Part 7: Complete FinOps Workflow

Workflow tổng hợp mô phỏng vòng đời tối ưu chi phí end-to-end:

1. Quan sát trạng thái GPU cluster.
2. Submit workload nặng.
3. Trigger autoscaler để đánh giá nhu cầu scale.
4. Chụp cost snapshot.
5. Sinh recommendation tối ưu.
6. Dùng spot instance để giảm chi phí.
7. Hoàn tất workload và ghi nhận billing.

Nhận xét: quy trình này thể hiện cách GPU FinOps hoạt động trong thực tế: đo lường trước, hành động dựa trên dữ liệu, sau đó ghi nhận lại chi phí và đánh giá hiệu quả tối ưu.

## 4. Phân tích real GPU workload

Part 8 chạy workload GPU thực tế trên Kaggle/Colab. Notebook cài `torch`, `torchvision`, `pynvml`, phát hiện GPU thực tế, sau đó train model ở hai chế độ FP32 và Mixed Precision AMP.

FP32 là baseline ổn định nhưng dùng nhiều memory và thường chậm hơn. AMP sử dụng mixed precision để giảm memory footprint và tận dụng Tensor Core nếu GPU hỗ trợ. Kết quả kỳ vọng là AMP giảm thời gian training và giảm chi phí theo epoch, trong khi accuracy không giảm đáng kể.

Các chỉ số cần đối chiếu nằm trong các screenshot `part8_fp32_summary.png`, `part8_amp_summary.png`, `part8_fp32_vs_amp_comparision.png` và `part8_real_gpu_cost_report.png`:

| Chỉ số | Cách đọc kết quả | Ý nghĩa FinOps |
|---|---|---|
| Total training time | So sánh thời gian tổng của FP32 và AMP | Runtime giảm thì chi phí GPU giảm |
| Peak memory | So sánh memory peak của hai chế độ | Memory thấp hơn giúp chạy batch lớn hơn hoặc dùng GPU nhỏ hơn |
| Estimated cost | So sánh cost report đã gửi lên gateway | Cost phản ánh trực tiếp runtime và GPU pricing |
| Accuracy | So sánh độ chính xác sau training | Optimization chỉ hợp lệ nếu accuracy không giảm đáng kể |

Nhận xét: AMP là một optimization có tỷ lệ lợi ích/công sức cao. Trong phần lớn workload deep learning, đây là bước nên thử sớm vì có thể giảm runtime, memory và cost mà không cần thay đổi kiến trúc lớn.

## 5. Advanced GPU Cost Optimization

### 5.1 Multi-GPU Cost Analysis

Phần multi-GPU analysis cho thấy tăng số GPU không đồng nghĩa với speedup tuyến tính. Ví dụ, 2 GPU có thể chỉ đạt khoảng 1.8x speedup, 4 GPU đạt khoảng 3.2x và 8 GPU đạt khoảng 5.6x do overhead communication, data loading và synchronization.

Kết quả cần đánh giá hai góc nhìn:

- Lowest total cost: số GPU có tổng chi phí thấp nhất.
- Best cost/performance: số GPU có chi phí trên mỗi đơn vị speedup tốt nhất.

Nhận xét: lựa chọn GPU count cần cân bằng giữa deadline và chi phí. Một GPU có thể rẻ nhất nhưng chạy lâu; nhiều GPU có thể hoàn thành nhanh hơn nhưng tổng chi phí cao hơn vì scaling không tuyến tính.

### 5.2 Project Cost Forecasting

Forecasting chia dự án thành nhiều phase: data preparation, model training, hyperparameter tuning và evaluation. Mỗi phase có loại GPU, số GPU, thời lượng và mức uncertainty riêng.

Với dữ liệu mẫu trong notebook:

- Base cost: khoảng `$3,551.20`
- Contingency 20%: khoảng `$710.24`
- Expected total: khoảng `$4,261.44`
- 95% confidence range: khoảng `$2,913.09` đến `$5,609.79`

Nhận xét: forecast giúp nhìn thấy rủi ro vượt ngân sách trước khi chạy toàn bộ dự án. Hyperparameter tuning thường là phase có uncertainty cao vì số lần thử nghiệm khó dự đoán.

### 5.3 Optimization Opportunity Analysis

Notebook ưu tiên các chiến lược tối ưu dựa trên savings, effort, risk và dependency. Các chiến lược gồm AMP, spot instance, batch-size optimization, early stopping và đổi GPU type.

Với cấu hình mẫu 4x A100 chạy 100 giờ, baseline cost khoảng `$1,468.00`. Mô hình roadmap cho thấy nếu áp dụng nhiều chiến lược theo thứ tự ưu tiên, chi phí có thể giảm đáng kể. Tuy nhiên, savings cộng dồn cần được hiểu theo mô hình ước lượng; trong thực tế cần đo lại sau từng thay đổi.

Nhận xét: không nên chỉ chọn strategy có savings cao nhất. Spot instance tiết kiệm lớn nhưng risk cao; AMP tiết kiệm thấp hơn spot nhưng effort thấp và risk thấp, do đó thường là quick win tốt.

### 5.4 Integrated Cost Dashboard

Dashboard tổng hợp gồm sáu biểu đồ:

1. Multi-GPU total cost.
2. Scaling efficiency.
3. Project forecast range.
4. Phase cost breakdown.
5. Savings vs effort matrix.
6. Cumulative savings roadmap.

Nhận xét: dashboard giúp gom nhiều quyết định FinOps vào một màn hình duy nhất, hỗ trợ ra quyết định giữa engineering, finance và project management.

### 5.5 Challenge Strategy

Scenario challenge là fine-tuning LLM với baseline 8x A100 trong 200 giờ. Baseline cost:

```text
8 × 200 × $3.67 = $5,872.00
```

Baseline vượt ngân sách `$5,000`, vì vậy cần optimization. Chiến lược đề xuất:

1. Giữ 8x A100 để đáp ứng deadline 2 tuần.
2. Bật AMP để giảm runtime và memory với rủi ro accuracy thấp.
3. Dùng spot instance có checkpoint để giới hạn preemption risk ở mức medium.
4. Tối ưu batch size để tăng utilization.
5. Dùng early stopping để tránh train thừa epoch.

Nhận xét: strategy này đáp ứng mục tiêu giảm chi phí theo roadmap, nhưng forecast có uncertainty vẫn có thể vượt ngân sách. Vì vậy cần giám sát cost theo ngày, đặt budget alert và checkpoint thường xuyên.

## 6. Kết luận và bài học

Qua bài lab, các kỹ năng chính đã thực hành gồm:

- Triển khai hệ thống mô phỏng GPU FinOps bằng Docker Compose.
- Theo dõi GPU utilization, memory, power và trạng thái workload.
- Ghi nhận billing theo loại GPU, số GPU và thời lượng chạy.
- So sánh on-demand và spot instance.
- Cấu hình autoscaling theo threshold và cooldown.
- Tạo cost snapshot, waste report và optimization recommendation.
- Trực quan hóa cost breakdown và time-series cost.
- So sánh FP32 với AMP trên workload GPU thực tế.
- Forecast chi phí dự án và thiết kế roadmap tối ưu.

Các chiến lược tối ưu hiệu quả nhất:

1. Dùng AMP cho workload deep learning nếu accuracy ổn định.
2. Right-size GPU theo nhu cầu thực tế thay vì luôn dùng GPU mạnh nhất.
3. Scale down GPU idle để giảm waste.
4. Dùng spot instance cho workload có checkpoint/retry.
5. Theo dõi cost theo phase và đặt budget alert.
6. Đánh giá multi-GPU scaling trước khi tăng số lượng GPU.

Kết luận: GPU FinOps không chỉ là giảm chi phí, mà là tối ưu quan hệ giữa chi phí, hiệu năng, deadline và rủi ro. Một quy trình tốt cần đo lường liên tục, trực quan hóa rõ ràng, áp dụng optimization có ưu tiên và kiểm chứng lại bằng dữ liệu thực tế.

## 7. Checklist bài nộp

- Notebook đã điền `STUDENT_NAME` và `STUDENT_ID`.
- Notebook đã cập nhật `GATEWAY_URL` từ tunnel.
- Các cell Part 1 đến Part 8.5 đã chạy và giữ output.
- Screenshot có header thông tin sinh viên.
- File chart đã được lưu:
  - `finops_cost_breakdown.png`
  - `finops_timeseries.png`
  - `real_gpu_comparison.png`
  - `real_gpu_telemetry.png` nếu có telemetry
  - `cost_per_epoch.png`
  - `multi_gpu_scaling.png`
  - `project_forecast.png`
  - `optimization_roadmap.png`
  - `advanced_finops_dashboard.png`
- Notebook hoàn chỉnh được nộp kèm source repository.
