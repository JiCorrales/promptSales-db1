CREATE VIEW dbo.v_NegativeSentiment AS
SELECT 
  a.AdId AS AdId,
  a.CampaignId   AS CampaignId,
  sf.FeelingScore,
  sf.SampleSize
FROM Ads a
JOIN SocialFeeling sf ON sf.AdId = a.AdId
WHERE sf.FeelingScore <= -0.5;  
