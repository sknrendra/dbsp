-- Buat remove sort
CREATE NONCLUSTERED INDEX IX_SP1ORDERSENDING_PO_GRID
ON dbo.SP1ORDERSENDING (DocNo, VendorCode, PlantCode, VendorGroup, PoNum)
INCLUDE (OrderDate, KanbanCardQty, OrderType, POType, ReviseFlag, CrossDock, DownloadFrequency, DownloadFlag);

-- Buat cek mandatory
CREATE NONCLUSTERED INDEX IX_SP1ORDERSENDING_ORDERDATE
ON dbo.SP1ORDERSENDING (OrderDate)
INCLUDE (DocNo, VendorCode, PlantCode, VendorGroup, PoNum, KanbanCardQty,
         OrderType, POType, ReviseFlag, CrossDock, DownloadFrequency, DownloadFlag);

