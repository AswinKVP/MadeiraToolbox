/*
Source: https://www.sqlservercentral.com/blogs/using-sys-dm_os_ring_buffers-to-troubleshoot-connectivity-issues-1
*/
;WITH RingBufferConnectivity as
(   SELECT
	ring_buffer_type,
	records.record.value('(/Record/@id)[1]', 'int') AS [RecordID],
	records.record.value('(/Record/ConnectivityTraceRecord/RecordType)[1]', 'varchar(max)') AS [RecordType],
	records.record.value('(/Record/ConnectivityTraceRecord/RecordTime)[1]', 'datetime') AS [RecordTime],
	records.record.value('(/Record/ConnectivityTraceRecord/SniConsumerError)[1]', 'int') AS [Error],
	records.record.value('(/Record/ConnectivityTraceRecord/State)[1]', 'int') AS [State],
	records.record.value('(/Record/ConnectivityTraceRecord/Spid)[1]', 'int') AS [Spid],
	records.record.value('(/Record/ConnectivityTraceRecord/RemoteHost)[1]', 'varchar(max)') AS [RemoteHost],
	records.record.value('(/Record/ConnectivityTraceRecord/RemotePort)[1]', 'varchar(max)') AS [RemotePort],
	records.record.value('(/Record/ConnectivityTraceRecord/LocalHost)[1]', 'varchar(max)') AS [LocalHost],
	records.record.query('/Record/ConnectivityTraceRecord/TdsDisconnectFlags') AS [TdsDisconnectFlags],
	records.record.query('.') AS [Details]
    FROM
    (   SELECT CAST(record as xml) AS record_data, ring_buffer_type
        FROM sys.dm_os_ring_buffers
        WHERE ring_buffer_type= 'RING_BUFFER_CONNECTIVITY'
    ) TabA
    CROSS APPLY record_data.nodes('//Record') AS records (record)
)
SELECT TOP 1000 RBC.*
, (
SELECT cast(node_xml.query('local-name(.)') as varchar(1000)) AS TdsDisconnectAttribute
FROM [TdsDisconnectFlags].nodes('//TdsDisconnectFlags/*[text()="1"]') AS TDS(node_xml)
FOR XML PATH(''), TYPE
) AS TdsDisconnectionReasons
, m.text AS ErrorMsg
FROM RingBufferConnectivity RBC
LEFT JOIN sys.messages M ON
    RBC.Error = M.message_id AND M.language_id = 1033
WHERE RBC.RecordType IN ('Error','ConnectionClose') --Comment Out to see all RecordTypes
ORDER BY RBC.RecordTime DESC