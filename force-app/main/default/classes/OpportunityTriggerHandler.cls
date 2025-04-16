public with sharing class OpportunityTriggerHandler extends TriggerHandler {
    private static Boolean hasAlreadyRun = false;
    private static Boolean hasAlreadyRunInsert = false; // Add this line

    protected override void beforeInsert() {
        setTypeForOpportunities((List<Opportunity>) Trigger.new);
    }

    protected override void beforeUpdate() {
        validateOpportunityAmount((List<Opportunity>) Trigger.new);
        setPrimaryContactCEO((List<Opportunity>) Trigger.new);
    }

    protected override void beforeDelete() {
        preventClosedOpportunityDeletion((List<Opportunity>) Trigger.old);
    }

    protected override void afterInsert() {

        if (Trigger.isInsert && Trigger.isAfter && !hasAlreadyRunInsert) { 
            hasAlreadyRunInsert = true; // Add this line
            createFollowUpTasks((List<Opportunity>) Trigger.new);
        }
    }

    protected override void afterUpdate() {
        if (hasAlreadyRun) return;
        hasAlreadyRun = true;

        updateOpportunityDescriptionOnStageChange((List<Opportunity>) Trigger.new, (Map<Id, Opportunity>) Trigger.oldMap);
    }

    protected override void afterDelete() {
        notifyOpportunityDeletion((List<Opportunity>) Trigger.old);
    }

    protected override void afterUndelete() {
        assignPrimaryContactVP((List<Opportunity>) Trigger.new);
    }

    

    private void setTypeForOpportunities(List<Opportunity> opps) {
        for (Opportunity opp : opps) {
            if (opp.Type == null) {
                opp.Type = 'New Customer';
            }
        }
    }

    private void validateOpportunityAmount(List<Opportunity> opps) {
        for (Opportunity opp : opps) {
            if (opp.Amount != null && opp.Amount < 5000) {
                opp.addError('Opportunity amount must be greater than 5000');
            }
        }
    }

    private void setPrimaryContactCEO(List<Opportunity> opps) {
        assignPrimaryContactByTitle(opps, 'CEO');
    }

    private void preventClosedOpportunityDeletion(List<Opportunity> opps) {
        for (Opportunity opp : opps) {
            if (opp.StageName == 'Closed Won' || opp.StageName == 'Closed Lost') {
                opp.addError('Cannot delete closed opportunity');
            }
        }
    }

    private void createFollowUpTasks(List<Opportunity> opps) {
        List<Task> tasks = new List<Task>();
        for (Opportunity opp : opps) {

            if (opp.IsDeleted == false) {
                Task t = new Task(
                    Subject = 'Follow up on Opportunity',
                    WhatId = opp.Id,
                    OwnerId = opp.OwnerId,
                    ActivityDate = Date.today().addDays(3)
                );
                if (opp.Primary_Contact__c != null) {
                    t.WhoId = opp.Primary_Contact__c;
                }
                tasks.add(t);
            }
        }
        if (!tasks.isEmpty()) {
            insert tasks;
        }
    }

    private void updateOpportunityDescriptionOnStageChange(List<Opportunity> newOpps, Map<Id, Opportunity> oldOpps) {
        List<Opportunity> oppsToUpdate = new List<Opportunity>();

        Map<Id, Opportunity> freshOpps = new Map<Id, Opportunity>([SELECT Id, Description 
                                                                FROM Opportunity 
                                                                WHERE Id IN :newOpps
        ]);

        for (Opportunity opp : newOpps) {
            Opportunity oldOpp = oldOpps.get(opp.Id);

            if (opp.StageName != oldOpp.StageName) {
                String existingDescription = freshOpps.get(opp.Id).Description != null
                    ? freshOpps.get(opp.Id).Description
                    : '';

                Opportunity updateOpp = new Opportunity(
                    Id = opp.Id,
                    Description = existingDescription + '\nStage Change:' + opp.StageName + ':' + Datetime.now().format()
                );
                oppsToUpdate.add(updateOpp);
            }
        }

        if (!oppsToUpdate.isEmpty()) {
            update oppsToUpdate;
        }
    }

    private void notifyOpportunityDeletion(List<Opportunity> opps) {
        List<Task> tasks = new List<Task>();
        for (Opportunity opp : opps) {
            
            Task t = new Task(
                Subject = 'Opportunity Deleted',
                OwnerId = opp.OwnerId,
                ActivityDate = Date.today()
            );
            tasks.add(t);
        }
        if (!tasks.isEmpty()) {
            insert tasks;
        }
    }

    private void assignPrimaryContactVP(List<Opportunity> opps) {
        assignPrimaryContactByTitle(opps, 'VP Sales');
    }

    private void assignPrimaryContactByTitle(List<Opportunity> opps, String title) {
        Set<Id> accountIds = new Set<Id>();
        for (Opportunity opp : opps) {
            if (opp.AccountId != null) {
                accountIds.add(opp.AccountId);
            }
        }

        if (accountIds.isEmpty()) return;

        Map<Id, Contact> accountIdToContact = new Map<Id, Contact>();
        for (Contact con : [SELECT Id, AccountId 
                            FROM Contact 
                            WHERE AccountId IN :accountIds AND Title = :title ORDER BY FirstName ASC
        ]) {
            accountIdToContact.put(con.AccountId, con);
        }

        List<Opportunity> oppsToUpdate = new List<Opportunity>();

        for (Opportunity opp : opps) {
            if (accountIdToContact.containsKey(opp.AccountId)) {

                if (Trigger.isBefore) {
                    opp.Primary_Contact__c = accountIdToContact.get(opp.AccountId).Id;

                } else if (Trigger.isAfter) {
                    Opportunity updateOpp = new Opportunity(
                        Id = opp.Id,
                        Primary_Contact__c = accountIdToContact.get(opp.AccountId).Id
                    );
                    oppsToUpdate.add(updateOpp);
                }
            }
        }

        if (!oppsToUpdate.isEmpty()) {
            update oppsToUpdate;
        }
    }
}







