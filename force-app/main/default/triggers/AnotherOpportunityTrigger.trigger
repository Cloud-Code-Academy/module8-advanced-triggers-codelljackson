/*
AnotherOpportunityTrigger Overview

This trigger was initially created for handling various events on the Opportunity object. It was developed by a prior developer and has since been noted to cause some issues in our org.

IMPORTANT:
- This trigger does not adhere to Salesforce best practices.
- It is essential to review, understand, and refactor this trigger to ensure maintainability, performance, and prevent any inadvertent issues.

ISSUES:
Avoid nested for loop - 1 instance
Avoid DML inside for loop - 1 instance
Bulkify Your Code - 1 instance
Avoid SOQL Query inside for loop - 2 instances
Stop recursion - 1 instance

RESOURCES: 
https://www.salesforceben.com/12-salesforce-apex-best-practices/
https://developer.salesforce.com/blogs/developer-relations/2015/01/apex-best-practices-15-apex-commandments
*/
trigger AnotherOpportunityTrigger on Opportunity (before insert, after insert, before update, after update, before delete, after delete, after undelete) {
    
    if (Trigger.isBefore && Trigger.isInsert) {
    
        for (Opportunity opp : Trigger.new) {
        
            if (opp.Type == null){   // Set default Type for new Opportunities
            opp.Type = 'New Customer'; 

        }
    }   
}       
        if (Trigger.isBefore && Trigger.isDelete){
            
            for (Opportunity oldOpp : Trigger.old){  // Prevent deletion of closed Opportunities
                if (oldOpp.IsClosed){
                    oldOpp.addError('Cannot delete closed opportunity');
                }
            }
        }
    
        if (Trigger.isAfter && Trigger.isInsert){
            
            List<Task> tskToInsert = new List<Task>(); 

            for (Opportunity opp : Trigger.new){  // Create a new Task for newly inserted Opportunities
                
                Task tsk = new Task();
                tsk.Subject = 'Call Primary Contact';
                tsk.WhatId = opp.Id;
                tsk.WhoId = opp.Primary_Contact__c;
                tsk.OwnerId = opp.OwnerId;
                tsk.ActivityDate = Date.today().addDays(3);
                tskToInsert.add(tsk);
            }
            if(!tskToInsert.isEmpty()) {
                insert tskToInsert;
            } 
        }
            if (Trigger.isAfter && Trigger.isUpdate) {

                
                for (Opportunity opp : Trigger.new){  // Append Stage changes in Opportunity Description
                    Opportunity oldOpp = Trigger.oldMap.get(opp.Id); 
                
                    if (opp.StageName != oldOpp.StageName){
                        if (opp.Description == null){
                            opp.Description = ''; 
                        }
                        opp.Description += '\n Stage Change:' + opp.StageName + ':' + DateTime.now().format();
                    }
                }  
            }                  
        // Send email notifications when an Opportunity is deleted 
            //if (Trigger.isDelete){
            //notifyOwnersOpportunityDeleted(Trigger.old);
         
        // Assign the primary contact to undeleted Opportunities
        //else if (Trigger.isUndelete){
           // assignPrimaryContact(Trigger.newMap);
        
    
    /*
    notifyOwnersOpportunityDeleted:
    - Sends an email notification to the owner of the Opportunity when it gets deleted.
    - Uses Salesforce's Messaging.SingleEmailMessage to send the email.
    */
    private static void notifyOwnersOpportunityDeleted(List<Opportunity> opps) {
        
        Set<Id> ownerId = new Set<Id>(); 

        for (Opportunity opp : opps){
            ownerId.add(opp.OwnerId); 
        }
        Map<Id, User> userById = new Map<Id, User>(
            [SELECT Id, Email FROM User WHERE Id IN :ownerId]); 
        
        List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();

        for(Opportunity opp : opps){

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

            mail.setToAddresses(new String[] { userById.get(opp.OwnerId).Email});
            mail.setSubject('Opportunity Deleted : ' + opp.Name);
            mail.setPlainTextBody('Your Opportunity: ' + opp.Name +' has been deleted.');
            mails.add(mail);
        }   
            if (!mails.isEmpty()) {
                Messaging.sendEmail(mails); 
        }    
    }
       // try {
          //  Messaging.sendEmail(mails);
       // } catch (Exception e){
         //  System.debug('Exception: ' + e.getMessage());
       // }
   // }

    /*
    assignPrimaryContact:
    - Assigns a primary contact with the title of 'VP Sales' to undeleted Opportunities.
    - Only updates the Opportunities that don't already have a primary contact.
    */
    private static void assignPrimaryContact(Map<Id,Opportunity> oppNewMap) { 
        
        Set<Id> accIds = new Set<Id>(); 

        for (Opportunity opp : oppNewMap.values()){
            accIds.add(opp.AccountId);            
        }
        List<Contact> contacts = [SELECT Id, AccountId 
                                FROM Contact 
                                WHERE Title = 'VP Sales' 
                                AND AccountId IN :accIds];
        
        Map<Id, Contact> accountIdToContact = new Map<Id, Contact>();

            for (Contact con : contacts){
                accountIdToContact.put(con.AccountId, con); 
            } 
            List<Opportunity> oppsToUpdate = new List<Opportunity>();

            for (Opportunity opp : oppNewMap.values()){

                if (opp.Primary_Contact__c == null && accountIdToContact.containsKey(opp.AccountId)){

                Opportunity oppToUpdate = new Opportunity();
                oppToUpdate.Id = opp.Id;
                oppToUpdate.Primary_Contact__c = accountIdToContact.get(opp.AccountId).Id;
                oppsToUpdate.add(oppToUpdate);
                }

                if (!oppsToUpdate.isEmpty()){
                    update oppsToUpdate;
                }
            }
        }
    }