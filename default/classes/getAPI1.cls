public class getAPI1 {
    //private static final String ENDPOINT_URL = 'https://cqparts-3d06.restdb.io/rest/cqpart'; 
    //private static final String API_KEY = 'b96d75ce0f9f342d10af6710ef8ea7ed0ad06';
    private static final String CUSTOM_PERMISSION = 'Integration_Admin';
    
    
    public static void fetchDataFromEndpoint() {
        try {
            Run_Sync_API__mdt customMetadata = Run_Sync_API__mdt.getInstance('X1');
            String endpointUrl = customMetadata.Endpoint_URL__c;
            String apiKey = customMetadata.API_Key__c;
            
            HttpRequest request = new HttpRequest();
            request.setEndpoint(endpointUrl);
            request.setMethod('GET');
            request.setHeader('Content-Type', 'application/json');
            request.setHeader('x-api-key', apiKey);
            
            HttpResponse response = new Http().send(request);
            handleResponse(response);
        } catch (Exception e) {
            String errorMessage = 'Error: ' + e.getMessage();
            System.debug(errorMessage);
        }
    }
    
    private static void handleResponse(HttpResponse response) {
        if (response.getStatusCode() == 200) {
            String responseBody = response.getBody();
            String transformedResponse = transformResponse(responseBody);
            List<Object> jsonList = (List<Object>) JSON.deserializeUntyped(transformedResponse);
            
            List<SQX_Part__c> cqPartList = new List<SQX_Part__c>();
            Account highAcc = [SELECT Id FROM Account WHERE Name = 'High Volume' LIMIT 1];
            Account lowAcc = [SELECT Id FROM Account WHERE Name = 'Low Volume' LIMIT 1];
            
            for (Object obj : jsonList) {
                SQX_Part__c cqPart = new SQX_Part__c();
                cqPart.Name = (String) ((Map<String, Object>) obj).get('Part_Name');
                cqPart.Part_Number__c = (String) ((Map<String, Object>) obj).get('Id');
                cqPart.Active__c = true;
                
                Integer totalQuantityShipped = (Integer) ((Map<String, Object>) obj).get('Total_Quantity_Shipped');
                if (totalQuantityShipped < 99) {
                    cqPart.Account__c = lowAcc.Id;
                } else {
                    cqPart.Account__c = highAcc.Id;
                }
                
                cqPartList.add(cqPart);
            }
            
            //upsert cqPartList;
            
            List<Database.UpsertResult> upsertResults = Database.upsert(cqPartList, SQX_Part__c.Part_Number__c, false);
            
            for (Database.UpsertResult result : upsertResults) {
                if (result.isSuccess()) {
                    // Upsert operation succeeded for a record
                    System.debug('Upsert successful for record with Part Number: ' + result.getId());
                } else {
                    // Upsert operation failed for a record
                    for (Database.Error error : result.getErrors()) {
                        System.debug('Upsert error for record with Part Number: ' + error.getMessage());
                    }
                }
            }
        } else {
            String errorMessage = 'Error: ' + response.getStatusCode() + ' - ' + response.getStatus();
            System.debug(errorMessage);
        }
    }
    
    private static String transformResponse(String responseBody) {
        String response1 = responseBody.replace('_id', 'Id');
        String response2 = response1.replace('Part Name', 'Part_Name');
        String response3 = response2.replace('Total Quantity Shipped"', 'Total_Quantity_Shipped"');
        return response3;
    }
    
    private static Boolean hasCustomPermission() {
        return FeatureManagement.checkPermission(CUSTOM_PERMISSION);
    }
    
    
}