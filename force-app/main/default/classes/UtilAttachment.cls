/**
MIT License

Copyright (c) 2023 Vladislav Luzhnov

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

public without sharing class UtilAttachment {

    public final static String UTIL_ATTACH_001_FILE_NOT_FOUND = 'UTIL-ATTACH-001: No files found with the provided name: ';
    public final static String UTIL_ATTACH_002_FAILED_TO_DELETE_RECORD = 'UTIL-ATTACH-002: An error during DML operation on the attachment deletion. ';
    public final static String UTIL_ATTACH_003_DELETE_ATTACHMENT_ERROR = 'UTIL-ATTACH-003: Unexpected error during attachment deletion. ';
    public final static String UTIL_ATTACH_004_INSERT_ATTACHMENT_ERROR = 'UTIL-ATTACH-004: Unexpected error during attachment insertion. ';


    /**
    Deletes All Versions of the File Names from the Records
    */
    public static void deleteAllVersionsOfTheAttachment(Map<Id, String> fileNamesWithExtension) {
        try {
            Map<Id, List<ContentVersion>> contentVersions = getAllContentVersionsWithTheFileNameOnObject(fileNamesWithExtension);

            List<ContentVersion> allContentVersions = new List<ContentVersion>();
            for (List<ContentVersion> cvs : contentVersions.values()) {
                allContentVersions.addAll(cvs);
            }

            Set<Id> allContentDocumentIds = new Set<Id>();
            for (ContentVersion cv : allContentVersions) {
                allContentDocumentIds.add(cv.ContentDocumentId);
            }

            List<ContentDocument> contentDocuments = [SELECT Id FROM ContentDocument WHERE Id IN :allContentDocumentIds FOR UPDATE];

            try {
                delete contentDocuments;
            } catch (Exception e) {
                throw new UtilAttachmentException(UTIL_ATTACH_002_FAILED_TO_DELETE_RECORD + e.getMessage());
            }

        } catch (Exception e) {
            throw new UtilAttachmentException(UTIL_ATTACH_003_DELETE_ATTACHMENT_ERROR + e.getMessage());
        }
    }

    /**
    Deletes All Versions of the File Name from the Record
    */
    public static void deleteAllVersionsOfTheAttachment(Id objectWithAttachmentId, String fileNameWithExtension) {
        Map<Id, String> parametersMap = new Map<Id, String>();
        parametersMap.put(objectWithAttachmentId, fileNameWithExtension);

        deleteAllVersionsOfTheAttachment(parametersMap);
    }


    /**
    Is used for inserting ContentDocuments - Attachments for the custom objects.
    */
    public static void insertAttachment(Map<Id, AttachmentParameters> insertAttachmentParameters) {
        try {
            // Creating a new version
            Map<Id, ContentVersion> contentVersion = new Map<Id, ContentVersion>();

            Map<Id, String> fileNameWithExtensionRelatedToObjectIds = new Map<Id, String>();
            for (AttachmentParameters i : insertAttachmentParameters.values()) {
                fileNameWithExtensionRelatedToObjectIds.put(i.objectId, i.fileName + i.fileExtension);
                contentVersion.put(i.objectId, new ContentVersion());
            }

            //Select all versions of the document with the same name on the object.
            Map<Id, List<ContentVersion>> existingContentVersions = getAllContentVersionsWithTheFileNameOnObject(fileNameWithExtensionRelatedToObjectIds);

            // If we have other versions, we are going to reuse content document.
            for (Id i : insertAttachmentParameters.keySet()) {
                List<ContentVersion> cvs = existingContentVersions.get(i);
                if (cvs != null && cvs.size() > 0) {
                    contentVersion.get(i).ContentDocumentId = cvs.get(0).ContentDocumentId;
                    insertAttachmentParameters.get(i).existingContentDocument = true;
                }
            }

            // Setting other parameters of the Content Version
            for (Id i : contentVersion.keySet()) {
                contentVersion.get(i).ContentLocation = 'S'; // S specify this document is in SF, use E for external files
                contentVersion.get(i).PathOnClient = insertAttachmentParameters.get(i).fileName + insertAttachmentParameters.get(i).fileExtension; // The file's name, extension is very important here which will help the file in preview.
                contentVersion.get(i).Title = insertAttachmentParameters.get(i).fileName; // Display name of the files
                contentVersion.get(i).VersionData = Blob.valueOf(insertAttachmentParameters.get(i).fileBody); // converting your binary string to Blob
            }

            insert contentVersion.values();

            //Flipping map, as we need a Set of Content Version Ids and still need a mapping to the Object Id
            Set<Id> contentVersionId = new Set<Id>();
            for (Id i : contentVersion.keySet()) {
                contentVersionId.add(contentVersion.get(i).Id);
            }

            // If content version created for the first time, content document will be created as well. If not, should return existing value we used above
            Map<Id, ContentVersion> contentDocumentId = new Map<Id, ContentVersion>([SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id IN :contentVersionId]);

            List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();

            for (AttachmentParameters i : insertAttachmentParameters.values()) {
                if (!i.existingContentDocument) {
                    //Create ContentDocumentLink
                    ContentDocumentLink contentDocumentLink = new ContentDocumentLink();
                    contentDocumentLink.LinkedEntityId = i.objectId; // you can use objectId,GroupId etc
                    contentDocumentLink.ShareType = 'I'; // Inferred permission, checkout description of ContentDocumentLink object for more details
                    contentDocumentLink.Visibility = 'AllUsers';
                    contentDocumentLink.ContentDocumentId = contentDocumentId.get(contentVersion.get(i.objectId).Id).ContentDocumentId;

                    linksToInsert.add(contentDocumentLink);
                }
            }

            insert linksToInsert;

        } catch (Exception e) {
            throw new UtilAttachmentException(UTIL_ATTACH_004_INSERT_ATTACHMENT_ERROR + e.getMessage());
        }

    }

    /**
    Is used for inserting ContentDocument - from the String with the Body
    */
    public static void insertAttachment(Id objectId, String fileName, String fileExtension, String fileBody) {
        AttachmentParameters p = new AttachmentParameters(objectId, fileName, fileExtension, fileBody);
        Map<Id, AttachmentParameters> parametersMap = new Map<Id, AttachmentParameters>();
        parametersMap.put(objectId, p);

        insertAttachment(parametersMap);

    }

    // Get a List of the Attachment's content from the provided parent Custom object. Assumption is that file is text.
    public static List<ContentVersion> getAllContentVersionsWithTheFileNameOnObject(Id id, String fileNameWithExtension) {
        Map<Id, String> fileNameWithExtensionRelatedToObjectId = new Map<Id, String>();
        fileNameWithExtensionRelatedToObjectId.put(id, fileNameWithExtension);

        return getAllContentVersionsWithTheFileNameOnObject(fileNameWithExtensionRelatedToObjectId).get(id);
    }

    // Get a List of the Attachment's content from the provided parent Custom object. Assumption is that file is text.
    public static Map<Id, List<ContentVersion>> getAllContentVersionsWithTheFileNameOnObject(Map<Id, String> fileNameWithExtensionRelatedToObjectId) {
        List<ContentDocumentLink> contentDocumentLinks = [SELECT Id, ContentDocumentId, LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId IN :fileNameWithExtensionRelatedToObjectId.keySet() ORDER BY SystemModstamp DESC];

        Map<Id, Id> contentDocumentIds = new Map<Id, Id>();
        Set<Id> contentDocumentIdsAll = new Set<Id>();

        for (ContentDocumentLink cdl : contentDocumentLinks) {
            contentDocumentIds.put(cdl.ContentDocumentId, cdl.LinkedEntityId);
            contentDocumentIdsAll.add(cdl.ContentDocumentId);
        }

        List<ContentVersion> allContentVersions = [SELECT Id, Title, PathOnClient, VersionData, ContentLocation, CreatedDate, ContentDocumentId, IsLatest FROM ContentVersion WHERE PathOnClient IN :fileNameWithExtensionRelatedToObjectId.values() AND ContentDocumentId IN :contentDocumentIdsAll];

        Map<Id, List<ContentVersion>> allContentVersionsMapped = new Map<Id, List<ContentVersion>>();

        for (ContentVersion cv : allContentVersions) {
            allContentVersionsMapped.put(contentDocumentIds.get(cv.ContentDocumentId), new List<ContentVersion>());
        }

        for (ContentVersion cv : allContentVersions) {
            allContentVersionsMapped.get(contentDocumentIds.get(cv.ContentDocumentId)).add(cv);
        }

        Map<Id, List<ContentVersion>> contentVersionsMatchingFileName = new Map<Id, List<ContentVersion>>();

        for (Id i : allContentVersionsMapped.keySet()) {
            contentVersionsMatchingFileName.put(i, new List<ContentVersion>());
            for (ContentVersion cv : allContentVersionsMapped.get(i)) {
                if (cv.PathOnClient.equals(fileNameWithExtensionRelatedToObjectId.get(i))) {
                    contentVersionsMatchingFileName.get(i).add(cv);
                }
            }
        }
        return contentVersionsMatchingFileName;
    }

    //This method to be used only as private, as it's carrying a specific logic to return exception if nothing or too many records are found.
    @TestVisible
    private static String getLatestAttachmentContent(List<ContentVersion> attachmentContents) {
        for (ContentVersion cv : attachmentContents) {
            if (cv.IsLatest == true) {
                return cv.VersionData.toString();
            }
        }

        throw new UtilAttachmentException(UTIL_ATTACH_001_FILE_NOT_FOUND);
    }

    public static String getLatestAttachmentContent(Id objectId, String fileNameWithExtension) {
        List<ContentVersion> attachmentContents = getAllContentVersionsWithTheFileNameOnObject(objectId, fileNameWithExtension);

        if (attachmentContents == null || attachmentContents.size() == 0) {
            throw new UtilAttachmentException(UTIL_ATTACH_001_FILE_NOT_FOUND + fileNameWithExtension);
        }

        return getLatestAttachmentContent(attachmentContents);
    }

    public class AttachmentParameters {
        public Id objectId;
        public String fileName;
        public String fileExtension;
        public String fileBody;
        public Boolean existingContentDocument = false;

        public AttachmentParameters(Id objectId, String fileName, String fileExtension, String fileBody) {
            this.objectId = objectId;
            this.fileName = fileName;
            this.fileExtension = fileExtension;
            this.fileBody = fileBody;
        }
    }


    public class UtilAttachmentException extends Exception {} //NOPMD

}

