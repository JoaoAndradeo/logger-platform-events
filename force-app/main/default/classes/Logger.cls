/**
 * Logger para Apex e Flow.
 *
 * As entradas ficam em memória até o flush(). Isso publica os eventos
 * (Log_Event__e) e o registro em Log__c é gravado em outra transação,
 * então o log não some se a transação de negócio der rollback.
 *
 * Uso típico:
 *   Savepoint sp = Database.setSavepoint();
 *   try { ... } catch (Exception e) { Database.rollback(sp); Logger.error('Classe.metodo', e, recordId); }
 *   finally { Logger.flush(); }
 */
public with sharing class Logger {

    // Limite de eventos por chamada de EventBus.publish.
    public static final Integer FLUSH_CHUNK_SIZE = 200;
    private static final Integer MAX_TEXT_LENGTH = 32000;

    private static List<LoggerEntry> buffer = new List<LoggerEntry>();
    private static Boolean dispatchGuard = false;

    public static void debug(String source, String message) {
        write(LogLevel.DEBUG, 'Apex', source, message, null, null);
    }

    public static void info(String source, String message) {
        write(LogLevel.INFO, 'Apex', source, message, null, null);
    }

    public static void warn(String source, String message) {
        write(LogLevel.WARN, 'Apex', source, message, null, null);
    }

    public static void error(String source, String message) {
        write(LogLevel.ERROR, 'Apex', source, message, null, null);
    }

    public static void error(String source, String message, Id recordId) {
        write(LogLevel.ERROR, 'Apex', source, message, recordId, null);
    }

    public static void error(String source, Exception e, Id recordId) {
        write(LogLevel.ERROR, 'Apex', source, e.getMessage(), recordId, e.getStackTraceString());
    }

    /** Ponto de entrada geral. O Invocable de Flow também usa este método, com sourceType 'Flow'. */
    public static void write(LogLevel level, String sourceType, String source, String message, Id recordId, String stackTrace) {
        LogLevel effectiveLevel = (level == null) ? LogLevel.INFO : level;

        // Enquanto o handler grava os logs, qualquer novo log é descartado para não gerar loop.
        if (dispatchGuard) {
            System.debug(LoggingLevel.WARN, '[Logger] Log descartado durante a gravação: ' + source);
            return;
        }
        if (effectiveLevel.ordinal() < LogSettings.getMinimumLevel().ordinal()) {
            return;
        }

        buffer.add(new LoggerEntry(
            effectiveLevel, sourceType, source, message, recordId, stackTrace,
            UserInfo.getUserId(), Request.getCurrent().getRequestId(), Datetime.now()
        ));
        System.debug('[' + effectiveLevel.name() + '] ' + source + ': ' + message);

        if (buffer.size() >= FLUSH_CHUNK_SIZE) {
            flush();
        }
    }

    /** Publica os logs pendentes. Chame sempre no finally do ponto de entrada. */
    public static void flush() {
        if (buffer.isEmpty()) {
            return;
        }

        List<Log_Event__e> events = new List<Log_Event__e>();
        for (LoggerEntry entry : buffer) {
            events.add(toEvent(entry));
        }
        buffer = new List<LoggerEntry>();

        for (Integer start = 0; start < events.size(); start += FLUSH_CHUNK_SIZE) {
            Integer finish = Math.min(start + FLUSH_CHUNK_SIZE, events.size());
            List<Log_Event__e> chunk = new List<Log_Event__e>();
            for (Integer i = start; i < finish; i++) {
                chunk.add(events[i]);
            }
            publish(chunk);
        }
    }

    /** Usado pelo LogEventHandler enquanto grava os logs. */
    public static void setDispatchGuard(Boolean active) {
        dispatchGuard = active;
    }

    @TestVisible
    private static Integer pendingCount() {
        return buffer.size();
    }

    private static void publish(List<Log_Event__e> chunk) {
        for (Database.SaveResult result : EventBus.publish(chunk)) {
            if (!result.isSuccess()) {
                System.debug(LoggingLevel.ERROR, '[Logger] Falha ao publicar evento: ' + result.getErrors());
            }
        }
    }

    private static Log_Event__e toEvent(LoggerEntry entry) {
        return new Log_Event__e(
            Level__c = entry.level.name(),
            Source__c = truncate(entry.source, 255),
            Source_Type__c = truncate(entry.sourceType, 10),
            Message__c = truncate(entry.message, MAX_TEXT_LENGTH),
            Stack_Trace__c = truncate(entry.stackTrace, MAX_TEXT_LENGTH),
            Related_Record_Id__c = (entry.recordId == null) ? null : String.valueOf(entry.recordId),
            User_Id__c = (entry.userId == null) ? null : String.valueOf(entry.userId),
            Transaction_Id__c = truncate(entry.transactionId, 64),
            Logged_At__c = entry.loggedAt
        );
    }

    private static String truncate(String value, Integer maxLength) {
        if (value == null || value.length() <= maxLength) {
            return value;
        }
        return value.substring(0, maxLength);
    }

    /** Dados capturados no momento do log (usuário, transação e hora), não no momento da gravação. */
    private class LoggerEntry {
        final LogLevel level;
        final String sourceType;
        final String source;
        final String message;
        final Id recordId;
        final String stackTrace;
        final Id userId;
        final String transactionId;
        final Datetime loggedAt;

        LoggerEntry(LogLevel level, String sourceType, String source, String message, Id recordId,
                    String stackTrace, Id userId, String transactionId, Datetime loggedAt) {
            this.level = level;
            this.sourceType = sourceType;
            this.source = source;
            this.message = message;
            this.recordId = recordId;
            this.stackTrace = stackTrace;
            this.userId = userId;
            this.transactionId = transactionId;
            this.loggedAt = loggedAt;
        }
    }
}
