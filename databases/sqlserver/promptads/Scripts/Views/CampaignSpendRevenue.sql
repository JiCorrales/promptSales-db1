CREATE VIEW dbo.v_CampaignSpendRevenue AS
SELECT 
  a.CampaignId AS CampaignId,
  CONVERT(date, amd.PostTime) AS Fecha,
  SUM(amd.Cost)    AS Cost,
  SUM(amd.Revenue) AS Revenue
FROM Ads a
JOIN AdMetricsDaily amd ON amd.AdId = a.AdId
GROUP BY a.CampaignId, CONVERT(date, amd.PostTime);
