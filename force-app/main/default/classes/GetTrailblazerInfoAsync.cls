/**
* @author meruff
* @date 5/29/20
*
* A helper class for calling out to the Trailhead API and populating Trailblazer__c records.
*/
public class GetTrailblazerInfoAsync implements Queueable, Database.AllowsCallouts {
    public static final String TRAILHEAD_ME = 'https://trailblazer.me/id/';
    public static final String TRAILHEAD_ME_USERID = 'https://trailblazer.me/id?cmty=trailhead&uid=';
    public static final String GO_TRAILHEAD_API = 'https://go-trailhead-leaderboard-api.herokuapp.com/trailblazer/';
    public static final String JOB_NAME = 'Populate Trailblazers from GetTrailblazerInfoAsync';

    private Integer jobCount = 0;
    private List<Trailblazer__c> trailblazers;

    public GetTrailblazerInfoAsync(Integer count, List<Trailblazer__c> scope) {
        jobCount = count;
        trailblazers = scope;
    }

    public void execute(QueueableContext context) {
        if (trailblazers.isEmpty()) {
            return;
        }

        Trailblazer__c trailblazer = trailblazers[0];

        Trailblazer__c newBlazer = new Trailblazer__c();
        populateTrailblazerProfileData(newBlazer, getProfileData(trailblazer));
        populateTrailblazerProfileCountsData(newBlazer, getProfileCountData(trailblazer));
        populateTrailblazerSuperbadgeData(newBlazer, getSuperbadgeData(trailblazer));
        populateTrailblazerCertificationData(newBlazer, getCertificationData(trailblazer));

        if (!String.isBlank(newBlazer.Profile_Handle__c)
            && !String.isBlank(newBlazer.Name)
        ) {
            upsert newBlazer Profile_Handle__c;
        }

        trailblazers.remove(0);
        jobCount++;

        if (!trailblazers.isEmpty()) {
            if (jobCount <= 4) {
                if (!Test.isRunningTest()) {
                    System.enqueueJob(new GetTrailblazerInfoAsync(jobCount, trailblazers));
                }
            } else {
                System.scheduleBatch(new PopulateTrailblazers(trailblazers), JOB_NAME, 0);
            }
        }
    }

    /**
     * Calls out to the /profile/ endpoint to get a JSON response.
     *
     * @param trailblazer, the Trailblazer__c record to populate with response data.
     *
     * @return res.getBody(), the JSON response body returned from the endpoint.
     */
    public static String getProfileData(Trailblazer__c trailblazer) {
        String calloutURL = '';

        if (!String.isBlank(trailblazer.Profile_Handle__c)) {
            calloutURL = GO_TRAILHEAD_API + trailblazer.Profile_Handle__c + '/profile';
        } else {
            calloutURL = GO_TRAILHEAD_API + trailblazer.Profile_Id__c + '/profile';
        }

        return doCallout(calloutURL);
    }

    /**
     * Writes data from the /profile/ endpoint to the Trailblazer__c record.
     *
     * @param trailblazer, a Trailblazer__c record to write to.
     * @param resBody, the response body JSON to deserialize and write to the Trailblazer__c record.
     */
    public static void populateTrailblazerProfileData(Trailblazer__c trailblazer, String resBody) {
        if (resBody.contains('application-error') || String.isBlank(resBody)) {
            return;
        }

        ProfileData data = (ProfileData) JSON.deserialize(resBody.replaceAll('__c', ''), ProfileData.class);

        if (data.profileUser != null) {
            trailblazer.Profile_Id__c = data.profileUser.Id;
            trailblazer.Name = data.profileUser.FirstName + ' ' + data.profileUser.LastName;
            trailblazer.Profile_Photo__c = data.profilePhotoUrl;
            trailblazer.Profile_Handle__c = data.profileUser.TrailblazerId;
            trailblazer.Company_Institution__c = data.profileUser.CompanyName;
            trailblazer.Job_Title__c = data.profileUser.Title;
            trailblazer.Job_Role__c = data.profileUser.TBID_Role;

            if (!String.isBlank(data.profileUser.TrailblazerId)) {
                trailblazer.Profile_Link__c = TRAILHEAD_ME + data.profileUser.TrailblazerId;
            } else {
                trailblazer.Profile_Link__c = TRAILHEAD_ME_USERID + data.profileUser.Id;
            }
        }
    }

    /**
     * Calls out to the /trailblazer/ endpoint to get a JSON response.
     *
     * @param trailblazer, the Trailblazer__c record to populate with response data.
     *
     * @return res.getBody(), the JSON response body returned from the endpoint.
     */
    public static String getProfileCountData(Trailblazer__c trailblazer) {
        String calloutURL = '';

        if (!String.isBlank(trailblazer.Profile_Handle__c)) {
            calloutURL = GO_TRAILHEAD_API + trailblazer.Profile_Handle__c;
        } else {
            calloutURL = GO_TRAILHEAD_API + trailblazer.Profile_Id__c;
        }

        return doCallout(calloutURL);
    }

    /**
     * Writes data from the /trailblazer/ endpoint to the Trailblazer__c record.
     *
     * @param trailblazer, a Trailblazer__c record to write to.
     * @param resBody, the response body JSON to deserialize and write to the Trailblazer__c record.
     */
    public static void populateTrailblazerProfileCountsData(Trailblazer__c trailblazer, String resBody) {
        if (resBody.contains('application-error') || String.isBlank(resBody)) {
            return;
        }

        ProfileCountData data = (ProfileCountData) JSON.deserialize(resBody.replaceAll('__c', ''), ProfileCountData.class);

        if (data.value != null && !data.value.isEmpty() && data.value[0].ProfileCounts != null && !data.value[0].ProfileCounts.isEmpty()) {
            trailblazer.Points__c = data.value[0].ProfileCounts[0].EarnedPointTotal;
            trailblazer.Badges__c = data.value[0].ProfileCounts[0].EarnedBadgeTotal;
            trailblazer.Trails__c = data.value[0].ProfileCounts[0].CompletedTrailTotal;
            trailblazer.Rank__c = data.value[0].ProfileCounts[0].RankLabel.capitalize();
            trailblazer.Rank_Badge_Link__c = data.value[0].ProfileCounts[0].RankImageUrl;
        }
    }

    /**
     * Calls out to the /trailblazer/ endpoint to get a JSON response.
     *
     * @param trailblazer, the Trailblazer__c record to populate with response data.
     *
     * @return res.getBody(), the JSON response body returned from the endpoint.
     */
    public static String getSuperbadgeData(Trailblazer__c trailblazer) {
        String calloutURL = '';

        if (!String.isBlank(trailblazer.Profile_Handle__c)) {
            calloutURL = GO_TRAILHEAD_API + trailblazer.Profile_Handle__c + '/badges/superbadge';
        } else {
            calloutURL = GO_TRAILHEAD_API + trailblazer.Profile_Id__c + '/badges/superbadge';
        }

        return doCallout(calloutURL);
    }

    /**
     * Writes data from the /trailblazer/ endpoint to the Trailblazer__c record.
     *
     * @param trailblazer, a Trailblazer__c record to write to.
     * @param resBody, the response body JSON to deserialize and write to the Trailblazer__c record.
     */
    public static void populateTrailblazerSuperbadgeData(Trailblazer__c trailblazer, String resBody) {
        if (resBody.contains('application-error') || String.isBlank(resBody)) {
            return;
        }

        BadgeData data = (BadgeData) JSON.deserialize(resBody.replaceAll('__c', ''), BadgeData.class);

        if (data.value != null && !data.value.isEmpty() && data.value[0].EarnedAwards != null && !data.value[0].EarnedAwards.isEmpty()) {
            Integer count = 0;

            for (BadgeData.EarnedAwards award : data.value[0].EarnedAwards) {
                if (award.AwardType == 'Superbadge') count++;
            }

            trailblazer.Superbadges__c = count;
        } else {
            trailblazer.Superbadges__c = 0;
        }
    }

    /**
     * Calls out to the /trailblazer/ endpoint to get a JSON response.
     *
     * @param trailblazer, the Trailblazer__c record to populate with response data.
     *
     * @return res.getBody(), the JSON response body returned from the endpoint.
     */
    public static String getCertificationData(Trailblazer__c trailblazer) {
        String calloutURL = '';

        if (!String.isBlank(trailblazer.Profile_Handle__c)) {
            calloutURL = GO_TRAILHEAD_API + trailblazer.Profile_Handle__c + '/certifications';
        } else {
            calloutURL = GO_TRAILHEAD_API + trailblazer.Profile_Id__c + '/certifications';
        }

        return doCallout(calloutURL);
    }

    /**
     * Writes data from the /trailblazer/ endpoint to the Trailblazer__c record.
     *
     * @param trailblazer, a Trailblazer__c record to write to.
     * @param resBody, the response body JSON to deserialize and write to the Trailblazer__c record.
     */
    public static void populateTrailblazerCertificationData(Trailblazer__c trailblazer, String resBody) {
        if (resBody.contains('application-error') || String.isBlank(resBody)) {
            return;
        }

        CertificationData data = (CertificationData) JSON.deserialize(resBody.replaceAll('__c', ''), CertificationData.class);

        if (data != null && data.certificationsList != null && !data.certificationsList.isEmpty()) {
            trailblazer.Certifications__c = data.certificationsList.size();
        } else {
            trailblazer.Certifications__c = 0;
        }
    }

    /**
     * Creates a callout using the supplied URL.
     *
     * @param calloutURL, the URL to do a callout to.
     * @return res.getBody() the body of the callout response.
     */
    public static String doCallout(String calloutURL) {
        Http h = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(calloutURL);
        req.setMethod('GET');
        req.setTimeout(60000);
        HttpResponse res = h.send(req);

        return res.getBody();
    }
}