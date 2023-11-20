@IsTest
private class UtilAttachmentTest {

    @TestSetup
    static void setup() {
        // Random Object to be created to have an attachment on it
        Lead l1 = new Lead(
                LastName = 'Test1',
                Company = 'SYNC'
        );

        Lead l2 = new Lead(
                LastName = 'Test2',
                Company = 'SYNC'
        );

        List<Lead> leads = new List<Lead>{l1, l2};
        insert leads;
    }

    @IsTest
    static void testAttachmentInsertedOnce(){
        Lead l = [SELECT Id FROM Lead WHERE LastName='Test1' LIMIT 1];

        String fileName = 'Test';
        String fileExtension = '.txt';
        String fileBody = 'Test';

        Test.startTest();
        UtilAttachment.insertAttachment(l.Id, fileName, fileExtension, fileBody);
        Test.stopTest();

        List<ContentVersion> contentVersions = [SELECT Id, PathOnClient, Title FROM ContentVersion];

        System.assertEquals(1, contentVersions.size());
        System.assertEquals(fileName+fileExtension, contentVersions.get(0).PathOnClient);

    }

    @IsTest
    static void testAttachmentInsertedTwice(){
        Lead l = [SELECT Id FROM Lead  WHERE LastName='Test1' LIMIT 1];

        String fileName = 'Test';
        String fileExtension = '.txt';
        String fileBody = 'Test';
        String fileBody2 = 'Test2';

        Test.startTest();
        UtilAttachment.insertAttachment(l.Id, fileName, fileExtension, fileBody);
        UtilAttachment.insertAttachment(l.Id, fileName, fileExtension, fileBody2);
        Test.stopTest();

        List<ContentVersion> contentVersions = [SELECT Id, PathOnClient, Title, ContentDocumentId FROM ContentVersion];

        System.assertEquals(2, contentVersions.size());
        System.assertEquals(contentVersions.get(0).ContentDocumentId, contentVersions.get(1).ContentDocumentId);
        System.assertEquals(fileName+fileExtension, contentVersions.get(0).PathOnClient);
        System.assertEquals(fileName+fileExtension, contentVersions.get(1).PathOnClient);

    }

    @IsTest
    static void testDeleteAllAttachmentsForFileNameMoreThanOne(){
        Lead l = [SELECT Id FROM Lead  WHERE LastName='Test1' LIMIT 1];

        String fileName = 'Test';
        String fileExtension = '.txt';
        String fileBody = 'Test';

        UtilAttachment.insertAttachment(l.Id, fileName, fileExtension, fileBody);
        UtilAttachment.insertAttachment(l.Id, fileName, fileExtension, fileBody);

        Test.startTest();
        UtilAttachment.deleteAllVersionsOfTheAttachment(l.Id, fileName+fileExtension);
        Test.stopTest();


        List<ContentDocumentLink> contentDocumentLinks = [SELECT Id, ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :l.Id];

        Set<Id> contentDocumentIds = new Set<Id>();

        for (ContentDocumentLink c : contentDocumentLinks) {
            contentDocumentIds.add(c.ContentDocumentId);
        }

        List<ContentVersion> contentVersions = [SELECT Id, PathOnClient, Title FROM ContentVersion WHERE ContentDocumentId IN :contentDocumentIds];

        System.assertEquals(0, contentVersions.size());

    }

    @IsTest
    static void testGetAttachmentsContents(){
        Lead l = [SELECT Id FROM Lead  WHERE LastName ='Test1' LIMIT 1];

        String fileName = 'Test';
        String fileName2 = 'Test2';
        String fileExtension = '.txt';
        String fileBody = 'Test';
        String fileBody2 = 'Test2';

        UtilAttachment.insertAttachment(l.Id, fileName, fileExtension, fileBody);
        UtilAttachment.insertAttachment(l.Id, fileName, fileExtension, fileBody);

        UtilAttachment.insertAttachment(l.Id, fileName2, fileExtension, fileBody2);
        UtilAttachment.insertAttachment(l.Id, fileName2, fileExtension, fileBody2);

        List<ContentVersion> contentVersions = new List<ContentVersion>();

        Test.startTest();
        contentVersions = UtilAttachment.getAllContentVersionsWithTheFileNameOnObject(l.Id, fileName+fileExtension);
        Test.stopTest();

        System.assertEquals(2, contentVersions.size());

    }

    @IsTest
    static void testGetAttachmentsContentsMap(){
        Lead l = [SELECT Id FROM Lead  WHERE LastName='Test1' LIMIT 1];
        Lead l2 = [SELECT Id FROM Lead  WHERE LastName='Test2' LIMIT 1];

        String fileName = 'Test';
        String fileName2 = 'Test2';
        String fileExtension = '.txt';
        String fileBody = 'Test';
        String fileBody2 = 'Test2';

        UtilAttachment.insertAttachment(l.Id, fileName, fileExtension, fileBody);
        UtilAttachment.insertAttachment(l.Id, fileName, fileExtension, fileBody);

        UtilAttachment.insertAttachment(l.Id, fileName2, fileExtension, fileBody2);
        UtilAttachment.insertAttachment(l.Id, fileName2, fileExtension, fileBody2);

        UtilAttachment.insertAttachment(l2.Id, fileName, fileExtension, fileBody);
        UtilAttachment.insertAttachment(l2.Id, fileName2, fileExtension, fileBody2);

        Map<Id, String> fileNameWithExtensionRelatedToObjectId = new Map<Id, String>();
        fileNameWithExtensionRelatedToObjectId.put(l.Id, fileName+fileExtension);
        fileNameWithExtensionRelatedToObjectId.put(l2.Id, fileName+fileExtension);

        Map<Id,List<ContentVersion>> contentVersions = new Map<Id,List<ContentVersion>>();

        Test.startTest();
        contentVersions = UtilAttachment.getAllContentVersionsWithTheFileNameOnObject(fileNameWithExtensionRelatedToObjectId);
        Test.stopTest();

        System.assertEquals(2, contentVersions.size());

        Integer totalContentVersionsSize = 0;

        for(Id i: contentVersions.keySet()){
            totalContentVersionsSize = totalContentVersionsSize + contentVersions.get(i).size();
        }

        System.assertEquals(3, totalContentVersionsSize);

    }


    @IsTest
    static void testGetLatestAttachmentsContents(){
        Lead l = [SELECT Id FROM Lead  WHERE LastName='Test1' LIMIT 1];

        String fileName = 'Test';
        String fileExtension = '.txt';
        String fileBody = 'Test';
        String fileBody2 = 'Test2';

        UtilAttachment.insertAttachment(l.Id, fileName, fileExtension, fileBody);

        UtilAttachment.insertAttachment(l.Id, fileName, fileExtension, fileBody2);


        List<ContentVersion> contentVersions = new List<ContentVersion>();
        contentVersions = UtilAttachment.getAllContentVersionsWithTheFileNameOnObject(l.Id, fileName+fileExtension);

        String latestContent = '';

        Test.startTest();
        latestContent = UtilAttachment.getLatestAttachmentContent(contentVersions);
        Test.stopTest();

        System.assertEquals(fileBody2, latestContent);
    }

}