CREATE VIEW dbo.v_AdPerformance AS
SELECT 
  a.AdId         AS AdId,
  a.CampaignId             AS CampaignId,
  amd.PostTime             AS Fecha,
  amd.Impressions,
  amd.Clicks,
  amd.Interactions,
  amd.PublicReach,
  amd.HoursViewed,
  amd.Cost,
  amd.Revenue,
  sf.FeelingScore
FROM Ads a
LEFT JOIN AdMetricsDaily amd ON amd.AdId = a.AdId
LEFT JOIN SocialFeeling  sf  ON sf.AdId   = a.AdId;
