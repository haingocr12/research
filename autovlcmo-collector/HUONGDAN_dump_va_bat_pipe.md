# Hướng dẫn: dump MctHost + bắt named pipe để lấy struct và giao thức thật

Mục tiêu: lấy được (1) code đã giải nén của `MctHost.exe`, (2) tên named pipe và dữ liệu chạy
qua pipe giữa `AutoVLCMO.exe` ↔ `MctHost.exe`. Từ đó suy ra struct món đồ và định dạng gói lệnh
(bán/hủy đồ, giao dịch).

Toàn bộ là phân tích phần mềm của chính bạn để nghiên cứu. Vẫn nên làm trong môi trường cô lập.

---

## 0. Chuẩn bị môi trường (bắt buộc)

- Dùng **máy ảo Windows** (VMware/VirtualBox/Hyper-V), bật **Snapshot** trước khi bắt đầu để rollback.
- Đăng nhập bằng **tài khoản game phụ, không quan trọng** — quá trình dừng/đọc tiến trình có thể
  làm rớt hoặc treo game.
- Tắt Windows Defender real-time trong VM (nó hay xoá pe-sieve/x64dbg nhầm là hack tool).
- Tải công cụ (bản chính chủ):
  - **pe-sieve** + **hollows_hunter** (github: hasherezade/pe-sieve, hasherezade/hollows_hunter)
  - **x64dbg** (có sẵn x32dbg cho tiến trình 32-bit) — x64dbg.com
  - **Scylla** (đi kèm x64dbg, hoặc bản riêng) — để rebuild import nếu cần
  - **API Monitor v2** (rohitab) — cách bắt pipe nhanh, không cần debugger
  - **Process Hacker / System Informer** — xem PID, handle, thread
  - (tuỳ chọn) **PE-bear** hoặc **CFF Explorer** để xem PE sau khi dump

> Ghi nhớ từ phân tích tĩnh: cả AutoVLCMO và MctHost đều là **32-bit** → luôn dùng **x32dbg**,
> **pe-sieve32**, **API Monitor (32-bit)**. MctHost bị pack (VMProtect/Themida). AutoVLCMO có vài
> hàm bị làm rối luồng, trong đó có hàm mở pipe.

---

## PHẦN A — Dump MctHost.exe đã giải nện

Ý tưởng: file trên đĩa bị pack. Khi chạy, nó tự giải nén code thật vào bộ nhớ. Ta để nó chạy ổn
định vài phút (đã đăng nhập, đang đánh quái) rồi dump từ RAM.

### A1. Lấy PID của MctHost cần dump
- Mở auto, để 1 acc chạy cho đơn giản (đừng mở 16 acc như buổi trước, khó theo dõi).
- Mở **Process Hacker**, tìm cây: `AutoVLCMO.exe` → con `MctHost.exe ... -instance:client_N`.
- Ghi lại **PID** của MctHost đó. Chờ ~2–3 phút cho nó giải nén và chạy ổn định.

### A2. Dump bằng pe-sieve (cách chính)
Mở **cmd Administrator**, chạy:

```
pe-sieve32.exe /pid <PID_MctHost> /dmode 3 /shellc /data 3 /dir dump_mct
```

Giải thích cờ:
- `/dmode 3` : cố gắng dump + tự sửa lại PE cho chạy/đọc được (unmap → raw alignment).
- `/shellc`  : bắt cả shellcode vùng không thuộc module (VMProtect hay để code ở đó).
- `/data 3`  : dump cả vùng dữ liệu (giúp thấy struct trong .data/heap).
- Kết quả nằm trong `dump_mct\process_<PID>\`: các file `*.exe`, `*.dll`, `*.shc` + báo cáo JSON.

Nếu muốn "chụp" tự động mọi tiến trình khả nghi cùng lúc, dùng:
```
hollows_hunter32.exe /pname MctHost.exe /shellc /data 3 /dir dump_all
```

### A3. Kiểm tra bản dump
- Mở file `.exe` dump được bằng **PE-bear**: xem section, entropy. Nếu entropy các section code đã
  **giảm về mức bình thường (~6)** thay vì 7.9 như bản gốc → đã unpack được phần lớn.
- `strings -el` trên file dump: nếu giờ đọc được chuỗi có nghĩa (lệnh game, tên struct) → thành công.
- Nếu file dump không mở được import: dùng **Scylla** (bước A4).

### A4. (Nếu cần) rebuild Import bằng Scylla
- Trong x32dbg attach vào MctHost (xem Phần B cách attach), để nó dừng.
- Mở **Scylla** (Plugins → Scylla) → chọn process → **IAT Autosearch** → **Get Imports** →
  **Dump** → **Fix Dump** (trỏ vào file pe-sieve đã dump). Kết quả là file `*_SCY.exe` mở được import.

> Lưu ý VMProtect: một phần code có thể vẫn nằm trong máy ảo của protector (không unpack ra code x86
> thường). Đó là giới hạn bình thường — vẫn đủ để đọc struct dữ liệu và phần lớn logic không bị ảo hoá.
> Gửi mình file dump (.exe/.shc + báo cáo JSON của pe-sieve), mình phân tích tiếp.

---

## PHẦN B — Bắt named pipe bằng x32dbg (lấy tên pipe + dữ liệu)

Từ phân tích tĩnh AutoVLCMO: kênh IPC dùng **named pipe**, mở qua `CreateFileW` và chờ bằng
`WaitNamedPipeW`, đọc/ghi qua `ReadFile`/`WriteFile`. Ta đặt breakpoint tại các API này để đọc
**tên pipe** và **nội dung gói**.

### B1. Attach vào AutoVLCMO
- Mở **x32dbg** → File → Attach → chọn `AutoVLCMO.exe`.
- (AutoVLCMO nhẹ hơn và không bị pack nặng như MctHost, nên bắt ở đây dễ hơn.)

### B2. Đặt breakpoint để lấy TÊN pipe
Trong ô Command (dưới cùng x32dbg), gõ lần lượt:

```
bp CreateFileW
bp WaitNamedPipeW
```

- Nhấn **F9 (Run)**. Khi dừng ở `CreateFileW`, tham số đầu (`lpFileName`) nằm ở `[esp+4]`.
  Vào tab **Stack**, chuột phải dòng `[esp+4]` → *Follow DWORD in Dump*, hoặc gõ ở Command:
  ```
  dump [esp+4]
  ```
  Ô **Dump** sẽ hiện chuỗi Unicode. Tên pipe có dạng `\\.\pipe\XXXXX`. **Ghi lại chuỗi này.**
- `WaitNamedPipeW` cũng có `lpNamedPipeName` ở `[esp+4]` → cùng cách đọc, để xác nhận tên.

> Mẹo lọc: nếu CreateFileW dừng quá nhiều lần (mở cả file thường), đặt breakpoint có điều kiện để chỉ
> dừng khi là pipe. Trong x32dbg: chuột phải breakpoint CreateFileW → *Edit* → Condition:
> `utf16(mem([esp+4])) contains "\\pipe\\"`  (hoặc cứ F9 vài lần, để ý chuỗi bắt đầu bằng `\\.\pipe\`).

### B3. Bắt DỮ LIỆU đi qua pipe
Sau khi biết pipe được mở (có `HANDLE` trả về ở `eax` khi `CreateFileW` return), đặt tiếp:

```
bp ReadFile
bp WriteFile
```

Với mỗi lần dừng, tham số (32-bit, __stdcall) trên stack:
- `[esp+4]`  = hFile (handle) — so khớp với handle pipe ở B2 để lọc đúng.
- `[esp+8]`  = lpBuffer (con trỏ tới dữ liệu)
- `[esp+0C]` = nNumberOfBytesToRead/Write (số byte)

Cách đọc gói:
1. Khi dừng ở `WriteFile` (AutoVLCMO gửi lệnh xuống MctHost) hoặc `ReadFile` (nhận trạng thái):
2. Đọc số byte: ô Command `? [esp+c]` hoặc xem trực tiếp trên Stack.
3. Xem buffer: Command `dump [esp+8]` → ô Dump hiện các byte của gói. Chuột phải vùng Dump →
   *Binary → Save to file* để lưu từng gói ra file (đặt tên theo hành động bạn vừa làm trong game).

> Với ReadFile, dữ liệu **thật sự có** sau khi hàm return (buffer được điền khi trả về). Nên đặt thêm
> breakpoint ở lệnh ngay sau `call ReadFile`, hoặc dùng "Run till return" (Ctrl+F9) rồi mới `dump [buffer]`.

### B4. Ghép hành động ↔ gói (để giải mã giao thức)
Làm từng thao tác đơn lẻ trong game qua auto và lưu gói tương ứng, ví dụ:
- Nhặt **1** món đồ → lưu gói ReadFile ngay sau đó → đây là bản ghi 1 item (suy ra struct 1 phần tử).
- Bấm **bán 1 món** → lưu gói WriteFile → đây là lệnh bán (thấy opcode + chỉ số ô túi).
- Mở **giao dịch** giữa 2 acc → lưu chuỗi gói → thấy "tín hiệu giao dịch" và lệnh gửi đồ/đồng.

Ghi nhật ký kiểu: `thời điểm | hành động | Read/Write | số byte | tên file gói`.

---

## PHẦN C — Cách nhanh không cần debugger (API Monitor)

Nếu chỉ muốn xem nhanh tên pipe và luồng dữ liệu mà không rành x32dbg:

1. Mở **API Monitor (32-bit)** → **Run as admin**.
2. Ở khung *API Filter*, tick nhóm: **Data Access and Storage → File I/O** (gồm CreateFile, ReadFile,
   WriteFile) và **NamedPipe** APIs (WaitNamedPipe, CallNamedPipe, TransactNamedPipe...).
3. Menu **File → Monitor New Process** → chọn `AutoVLCMO.exe` (hoặc *Monitor Process* để attach nếu
   đang chạy). Nếu cần bắt cả phía MctHost thì cũng attach vào MctHost.
4. Cột *Summary* sẽ liệt kê từng call kèm tham số. Tìm `CreateFileW` có tên `\\.\pipe\...` → đó là pipe.
   Bấm vào call `ReadFile`/`WriteFile` → khung *Buffer* bên phải hiện hex nội dung gói → chuột phải → *Save*.

API Monitor tiện để **chụp toàn bộ luồng** rồi lọc sau; x32dbg tiện để **dừng đúng lúc và đọc sâu**.

---

## PHẦN D — Tìm struct món đồ từ dữ liệu bắt được

Sau khi có các gói (Phần B/C) hoặc bản dump bộ nhớ (Phần A), tìm struct 1 món đồ:

1. Chọn 1 món có thuộc tính bạn biết chắc: ví dụ đồ **3 sao**, phẩm chất **Tím**, **cấp 5**, phái X.
2. Trong gói/bộ nhớ, tìm các giá trị đó dưới dạng số nguyên nhỏ: `03` (sao), `05` (cấp), và một mã màu
   (thường 0..6 theo thang Trắng→Đỏ). Chúng thường nằm gần nhau trong 1 record cố định độ dài.
3. Đổi món khác (2 sao, cấp 10) rồi bắt lại → **so sánh 2 record** để xác định **offset** của từng trường
   (byte nào đổi từ 3→2 = trường sao; byte nào đổi 5→10 = cấp; v.v.). Đây là kỹ thuật "diff có kiểm soát".
4. Suy ra bảng túi = mảng các record độ dài cố định. Ghi lại: `offset 0 = itemId(4B)`, `offset ? = sao(1B)`,
   `offset ? = màu(1B)`, `offset ? = cấp(1B)`, `offset ? = cờ khóa(1B)`... (đối chiếu với các điều kiện lọc
   đã thấy trong UI: màu/sao/cấp/phái/khóa).

Với **giao dịch**, làm tương tự: bắt gói lúc "gửi đồng và giữ lại N" với N khác nhau (vd giữ 1000 vs 2000)
→ tìm byte chứa 1000/2000 (little-endian `E8 03` / `D0 07`) → xác định offset trường số đồng trong lệnh.

---

## Những gì cần gửi lại cho mình

Để mình phân tích tiếp và lập bảng struct/giao thức, bạn gửi:
1. **Tên pipe** đọc được (chuỗi `\\.\pipe\...`).
2. Vài **file gói** đã lưu, kèm nhãn hành động (nhặt 1 đồ / bán 1 đồ / gửi 1000 đồng...).
3. Thư mục **dump pe-sieve** của MctHost (file `.exe`/`.shc` + báo cáo `.json`).

> An toàn dữ liệu: gói tin có thể chứa tên nhân vật / thông tin acc phụ của bạn. Xem qua trước khi gửi.
> Đừng gửi gói lúc đang nhập mật khẩu (tránh lộ thông tin đăng nhập).

---

## Ghi chú kỹ thuật (từ phân tích tĩnh đã làm)

- Hàm mở pipe trong AutoVLCMO ở gần `0x401425` (`WaitNamedPipeW`) và `CreateFileW` `0x4012a8` — **bị làm
  rối luồng** (control-flow flattening), nên đọc tĩnh không ra tên pipe; phải bắt động như trên.
- AutoVLCMO **không** dùng ReadProcessMemory/WriteProcessMemory để trao đổi trạng thái game (chỉ có đúng
  1 hàm `0x63E8CE` dùng chúng để **vá dòng lệnh PEB** của MctHost). Vì vậy pipe (hoặc socket cục bộ) là
  kênh dữ liệu chính — đó là lý do trọng tâm đặt vào việc bắt pipe.
- MctHost là client game tự viết, giữ trạng thái thật; struct món đồ nằm trong bộ nhớ MctHost và/hoặc
  trong payload pipe → cả Phần A và Phần B đều dẫn tới cùng struct đó, bổ trợ nhau.
