/**
 * Grava os Log_Event__e em Log__c. Chamado pelo LogEventTrigger.
 *
 * Não lança exceção: se lançar, a plataforma reenfileira o evento. Erros são só registrados no debug log.
 */
public with sharing class LogEventHandler {

    public static void handle(List<Log_Event__e> events) {
        if (events == null || events.isEmpty()) {
            return;
        }

        Logger.setDispatchGuard(true);
        try {
            List<Log__c> logs = new List<Log__c>();
            for (Log_Event__e event : events) {
                logs.add(toLog(event));
            }

            // Gravação do sistema: o usuário que gerou o log já foi validado na origem.
            for (Database.SaveResult result : Database.insert(logs, false, AccessLevel.SYSTEM_MODE)) {
                if (!result.isSuccess()) {
                    System.debug(LoggingLevel.ERROR, '[LogEventHandler] Falha ao gravar log: ' + result.getErrors());
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, '[LogEventHandler] Erro inesperado: ' + e.getMessage());
        } finally {
            Logger.setDispatchGuard(false);
        }
    }

    @TestVisible
    private static Log__c toLog(Log_Event__e event) {
        return new Log__c(
            Level__c = LogSettings.parseLevel(event.Level__c, LogLevel.INFO).name(),
            Source__c = event.Source__c,
            Source_Type__c = 'Flow'.equalsIgnoreCase(event.Source_Type__c) ? 'Flow' : 'Apex',
            Message__c = event.Message__c,
            Stack_Trace__c = event.Stack_Trace__c,
            Related_Record_Id__c = event.Related_Record_Id__c,
            User__c = toUserId(event.User_Id__c),
            Transaction_Id__c = event.Transaction_Id__c,
            Logged_At__c = (event.Logged_At__c != null) ? event.Logged_At__c : Datetime.now()
        );
    }

    /** Devolve o Id apenas se for de um usuário. Caso contrário, null. */
    @TestVisible
    private static Id toUserId(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        try {
            Id candidate = Id.valueOf(value);
            return (candidate.getSObjectType() == User.SObjectType) ? candidate : null;
        } catch (Exception e) {
            return null;
        }
    }
}
