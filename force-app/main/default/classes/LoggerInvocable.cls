/**
 * Ação "Registrar log" para Flow.
 * Grava todas as linhas da invocação e faz um único flush no final.
 */
public with sharing class LoggerInvocable {

    public class Request {
        @InvocableVariable(label='Nível' required=true description='DEBUG, INFO, WARN ou ERROR. Valor inválido vira INFO.')
        public String level;

        @InvocableVariable(label='Origem' required=true description='Nome do Flow ou do elemento que gerou o log.')
        public String source;

        @InvocableVariable(label='Mensagem' required=true)
        public String message;

        @InvocableVariable(label='ID do registro relacionado')
        public Id recordId;
    }

    @InvocableMethod(label='Registrar log' description='Grava uma linha de log. A gravação acontece em outra transação, então sobrevive a rollback.' category='Logger')
    public static void log(List<Request> requests) {
        if (requests == null || requests.isEmpty()) {
            return;
        }
        try {
            for (Request req : requests) {
                Logger.write(
                    LogSettings.parseLevel(req.level, LogLevel.INFO),
                    'Flow',
                    req.source,
                    req.message,
                    req.recordId,
                    null
                );
            }
        } finally {
            Logger.flush();
        }
    }
}
