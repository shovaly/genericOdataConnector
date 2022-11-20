@istest
public with sharing class DataSourceConnectionTest {
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
            
            DataSourceConnectionSyncObjects sync = (DataSourceConnectionSyncObjects)MockCreator.createMock(DataSourceConnectionSyncObjects.class);
            DataSourceConnection conn = new DataSourceConnection(connectionParams);
            conn.objectSync = sync;
            List<DataSource.Table> tables = conn.sync();
        }
        
    }

    @IsTest
    public static void TestQuery(){
        
         System.runAs(adminUser)
        { 
            DataSourceConnectionIntegration integration = 
            (DataSourceConnectionIntegration)MockCreator.createMock(DataSourceConnectionIntegration.class);
            DataSource.QueryContext context = new DataSource.QueryContext();
            DataSource.ConnectionParams connectionParams = new DataSource.ConnectionParams();
            connectionParams.endpoint = 'http://someUrl';
            DataSourceConnection conn = new DataSourceConnection(connectionParams);
            conn.objectIntegration = integration;
            DataSource.TableResult table = conn.query(context);
        }
        
    }
}