========================================================
 BO THU THAP DU LIEU AutoVLCMO (game ban PC) - CHI DOC
========================================================

Muc dich: ghi lai xem AutoVLCMO / MctHost lam gi luc chay, de nghien cuu cach hoat dong.
Script CHI DOC va SAO CHEP. No KHONG sua, KHONG ghi, KHONG can thiep vao auto hay game.

------------------------------------------------
CACH DUNG
------------------------------------------------
1) Copy ca thu muc "autovlcmo-collector" nay ra may Windows dang chay auto.

2) Chuot phai vao "run.bat"  ->  Run as administrator.
   (Can quyen admin de doc duoc dong lenh va danh sach DLL cua tien trinh khac.)

3) Doi den khi thay dong mau xanh "San sang."
   -> Luc nay HAY MO AUTO va dung binh thuong khoang 3-5 phut,
      cho no lam vai chuc nang (dang nhap, danh quai, pho ban...).

4) Quay lai cua so mau den, NHAN PHIM  Q  de dung.
   Script se so sanh thu muc, dong goi va tao file:
        Output_<ngaygio>.zip   (nam ngay canh run.bat)

5) Gui file Output_....zip do lai cho nguoi phan tich.

------------------------------------------------
TRONG FILE ZIP CO GI
------------------------------------------------
- snapshot_before.txt / snapshot_after.txt : danh sach file trong thu muc auto truoc & sau khi chay
                                             (kem SHA256) -> thay MctHost da bung ra file gi.
- changed_files.txt   : rieng danh sach file MOI hoac BI DOI.
- files\...           : ban sao cac file cau hinh/DLL/xml/log moi-hoac-doi (chi file < 25MB,
                        khong copy lai chinh cac .exe goc).
- proc\proc_XXXX.txt  : moi vai giay mot lan - danh sach tien trinh lien quan (PID, tien trinh cha,
                        dong lenh) va cac module/DLL dang duoc nap vao game & MctHost.
- collector.log, system.txt : nhat ky va thong tin he thong.

------------------------------------------------
TUY CHON (khong bat buoc)
------------------------------------------------
Neu script khong tu tim ra thu muc auto, mo cua so PowerShell (admin) va chay tay:
    .\collect.ps1 -AutoDir "D:\Duong\Dan\AutoVLCMO"

Doi so giay giua moi lan chup (mac dinh 5):
    .\collect.ps1 -Interval 3

------------------------------------------------
LUU Y
------------------------------------------------
- proc\ va snapshot co the chua ten may / duong dan file cua ban. Neu ngai, cu xem qua
  truoc khi gui.
- Bo cong cu nay chi QUAN SAT. No khong lay mat khau, khong doc bo nho game,
  khong sua gi trong auto. Nhung phan sau (xem bo nho MctHost, bat goi tin mang) neu can
  se dung cong cu chuan cua Microsoft (Sysinternals) va ban tu chay, se huong dan rieng.
