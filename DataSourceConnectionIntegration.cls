public with sharing class DataSourceConnectionIntegration {
    private DataSource.ConnectionParams connectionParams;
    public MetadataParserSelector parserSelector;
    private string url;
    private User currentUser;
    private string priorityUrl; 
    private string priorityUserName;
    private string priorityPassword;

    public DataSourceConnectionIntegration(DataSource.ConnectionParams connectionParams) {
        this.connectionParams = connectionParams;
        parserSelector = new MetadataParserSelector();
        url = connectionParams.endpoint;
    }


    private void testMultipleEndPoints(){
        string currentUserName = this.connectionParams.username;
        this.currentUser = parserSelector.getPriorityEndpointForUser(currentUserName);
        system.debug('###this.currentUser.AboutMe:' + this.currentUser.AboutMe);
        string[] splitedDetails = this.currentUser.AboutMe.split(';');
        system.debug('###splitedDetails:' + splitedDetails);
        if(splitedDetails.size() == 0) {return;}
        this.priorityUrl = splitedDetails[0];
        this.priorityUserName = splitedDetails[1];
        this.priorityPassword = splitedDetails[2];
        this.url = priorityUrl;
    }

    private Blob testSetCred(){

        if(priorityUrl == ''){
            return Blob.valueOf(connectionParams.username + ':' + connectionParams.password);
        }
        return Blob.valueOf(priorityUserName + ':' + priorityPassword);
    }

    public DataSource.TableResult query(DataSource.QueryContext context) {
        
        try{
            //testMultipleEndPoints();
            string queriedTable = context.tableSelection.tableSelected;
            url += '/' + queriedTable;
            string keyField = parserSelector.getTableExternField(queriedTable);

            string queryString = '';
            string selectedColumns='$SELECT=';
             
            List<DataSource.ColumnSelection> selectedColumnsList = clearIrrelevantSelectedColumns(context.tableSelection.columnsSelected,queriedTable);

            system.debug('###full filter: ' + context.tableSelection.filter);
            if (context.tableSelection.filter != null && context.tableSelection.filter.subfilters == null) {
                queryString =  getQueryOdataFilter(context.tableSelection.filter,keyField);
            }
            

            if(context.tableSelection.filter != null && context.tableSelection.filter.subfilters != null){
                string compoundFilter = ' ' + getFilterParameters(context.tableSelection.filter.type) + ' ';
                List<DataSource.Filter> filters =  getFilters(context.tableSelection.filter);
                for(DataSource.Filter filter : filters){
                    
                    string innerCmpoundFilter = ' ' + getFilterParameters(filter.type) + ' ';
                    queryString += '(';
                    if(filter.subfilters == null){
                        queryString += getQueryOdataFilter(filter,keyField);
                        queryString += innerCmpoundFilter;
                    }
                    else{
                        for(DataSource.Filter subFilter : filter.subfilters){
                                queryString += getQueryOdataFilter(subFilter,keyField);
                                queryString += innerCmpoundFilter;
                            }
                    }
                    
                    queryString = queryString.removeEnd(innerCmpoundFilter);    
                    queryString += ')';
                    queryString += compoundFilter;
                }
                
                queryString = queryString.removeEnd(compoundFilter);    
            }
            
            if(selectedColumnsList != null && selectedColumnsList.size() > 0)
            {
                for(DataSource.ColumnSelection col : selectedColumnsList){

                    if(col.columnName == 'ExternalId') 
                    {
                        selectedColumns += keyField + ',';
                    }
                    else if (col.columnName == 'DisplayUrl') continue;
                    else{
                        selectedColumns += col.columnName + ',';
                    }
                }
                selectedColumns = selectedColumns.removeEnd(',');
            }
            if(selectedColumns == '$SELECT='){
                selectedColumns += keyField;
            }
            //This is a patch - When external Object was a related list in SF Object we failed extracting the externalId Field
            if(!selectedColumns.contains(keyField)){
                selectedColumns += ',' + keyField; 
            }
                List<Map<String, Object>> rows = getData(queryString,selectedColumns,keyField);
                DataSource.TableResult result = DataSource.TableResult.get(true, null, context.tableSelection.tableSelected, rows);
                return result;

            }
            catch(CustomGenericException e){
                
                system.debug('###error ' + e.getMessage());
                throw new CustomGenericException(e.getMessage());
            }
            catch(Exception e){
                system.debug('###error ' + e.getMessage());
            
                if(e.getMessage().startsWith('Exceeded max size limit') || e.getMessage().startsWith('String length exceeds maximum')) {
                    throw new LimitException('Exceeding maximum size limit , please refine your filters.');
                }
                return DataSource.TableResult.get(true, null, context.tableSelection.tableSelected, null);
            }
            
    }

    private List<DataSource.ColumnSelection>  clearIrrelevantSelectedColumns(List<DataSource.ColumnSelection> columns,string tableName ){
        List<DataSource.ColumnSelection> relevantColumns = new List<DataSource.ColumnSelection>();
        Set<string> externalFields = parserSelector.getTableFields(tableName);
        for(DataSource.ColumnSelection column : columns){
            if(externalFields.contains(column.columnName)) {
                relevantColumns.add(column);
            }
        }
        return relevantColumns;
    }

    private string getQueryOdataFilter(DataSource.Filter filter,string keyField){
        string columnName = filter.columnName;
        if(filter.columnName == 'ExternalId') 
        {
            columnName = keyField;
        }

        
        return columnName + ' ' +
                        getFilterParameters(filter.type) + ' ' + 
                        formatValue(filter.columnValue);
    }

    private object formatValue(object value){
        if(value instanceof string)
        {
            return '\'' + value + '\'';
        }
        return value;
    }

    private List<DataSource.Filter> getFilters(DataSource.Filter filter){
        if(filter.columnName == null && filter.subfilters != null){
            return filter.subfilters;
        }
        return getFilters(filter.subfilters[0]);
    }

    private string getFilterParameters(DataSource.FilterType filterParams){

        switch on filterParams {
            when EQUALS {
                return 'eq';
            }

            when NOT_EQUALS {
                return 'ne';
            }
            when AND_ {
                return 'AND';
            }
            when OR_ {
                return 'OR';
            }
            when GREATER_THAN {
                return 'gt';
            }
            when GREATER_THAN_OR_EQUAL_TO {
                return 'ge';
            }
            when LESS_THAN {
                return 'lt';
            }
            when LESS_THAN_OR_EQUAL_TO {
                return 'le';
            }
            
            when else {
                throw new CustomGenericException('Only the following filters '  + 
                'are supported: eq , ne , gt , ge , lt , le ');
            }
            
        }
    }
    private List<Map<String, Object>> getData(string queryString,string selectedColumns,string keyField){
        
        String responseBody = makeGetCallout(queryString,selectedColumns);
        if(responseBody == null || responseBody == '') return new List<Map<String, Object>>();
        List<Map<String, Object>> rows =new List<Map<String, Object>>();
        Map<String, Object> responseBodyMap = (Map<String, Object>)JSON.deserializeUntyped(responseBody);
        // Checks errors.
        handleErrors(responseBodyMap);

        List<Object> fileItems = (List<Object>)responseBodyMap.get('value');
        if (fileItems != null) {
            for (Integer i=0; i < fileItems.size(); i++) {
                Map<String, Object> item = (Map<String, Object>)fileItems[i];
                rows.add(createRow(item,keyField));
            }
        } else {
            rows.add(createRow(responseBodyMap,keyField));
        }
        return rows;
    }
    
    private void handleErrors(Map<String, Object> responseBodyMap){
        Map<String, Object> error =(Map<String, Object>)responseBodyMap.get('error');
        if (error!=null) {
            List<Object> errorsList =(List<Object>)error.get('errors');
            Map<String, Object> errors =(Map<String, Object>)errorsList[0];
            String errorMessage = (String)errors.get('message');
            throw new DataSource.OAuthTokenExpiredException(errorMessage);
        }
    }

    private Map<String, Object> createRow(Map<String, Object> item,string keyField){
        Map<String, Object> rows = new Map<String, Object>();
        String id ='';
        for(String key : item.keySet()){
            if(key == keyField){
                id =  '\''+ String.valueOf(item.get(key)) + '\'' ;
                rows.put('ExternalId', item.get(key));
                
            }
            rows.put(key, item.get(key));
        }
        //todo set  priority URL
        rows.put('DisplayUrl', id.replace('\'', '')); 
        
        return rows;
    }

     

    //Make a GET Callout
    private string makeGetCallout(string queryString,string selectedColumns) {
        Http httpProtocol = new Http();
        HttpRequest request = new HttpRequest();
        string paramvalue = getEncodedCreds();

        string fullUrl = url + '?' + selectedColumns;
        if(queryString != ''){
            fullUrl += '&$filter=' + EncodingUtil.urlEncode(queryString,'UTF-8') + '&$top=1000';
        }
        system.debug('###Url: ' + paramvalue + ' ' + fullUrl);
        request.setHeader('Authorization',paramvalue);
        request.setHeader('Accept-Encoding', 'gzip, deflate, br');
        request.setTimeout(120000);
        request.setEndPoint(fullUrl);
        request.setMethod('GET');
        
            HttpResponse response = httpProtocol.send(request);
            return response.getBody();
    }

    private string getEncodedCreds(){
        Blob beforeblob = Blob.valueOf(connectionParams.username + ':' + connectionParams.password);
        //beforeblob = testSetCred();
        return 'Basic ' + EncodingUtil.base64Encode(beforeblob);
    }
}