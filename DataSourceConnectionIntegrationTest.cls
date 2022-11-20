@istest
public with sharing class DataSourceConnectionIntegrationTest {
    private static User adminUser;
    static{
        //TODO: Add more user types once decided
        Id profileId =TestUtils.getProfileIdByName(TestUtils.ADMIN_PROFILE);
        adminUser = TestUtils.createUser(profileId);
    }

    @IsTest
    public static void TestSync(){

         System.runAs(adminUser)
        { 
            DataSource.ConnectionParams connectionParams = new DataSource.ConnectionParams();
            connectionParams.endpoint = 'http://somthing';
            MetadataParserSelector selector = 
            (MetadataParserSelector)MockCreator.createMock(MetadataParserSelector.class);
            DataSourceConnectionSyncObjects sync = (DataSourceConnectionSyncObjects)MockCreator.createMock(DataSourceConnectionSyncObjects.class);
            DataSourceConnectionIntegration integration = new DataSourceConnectionIntegration(connectionParams);
            integration.parserSelector = selector;
            DataSource.QueryContext context = new DataSource.QueryContext();
            context.tableSelection = new DataSource.TableSelection();
            context.tableSelection.tableSelected = 'someTable';
            context.tableSelection.filter = new DataSource.Filter();
            context.tableSelection.filter.columnName = 'someColumn';
            context.tableSelection.filter.columnValue = '5';
            context.tableSelection.filter.tableName = 'someTable';
            context.tableSelection.filter.type = DataSource.FilterType.EQUALS;
            
            DataSource.TableResult  result = integration.query(context);
        }
        
    }
}