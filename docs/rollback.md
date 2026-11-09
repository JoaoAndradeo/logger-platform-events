# Logs e rollback

Se a transação de negócio dá rollback, os registros gravados nela também são desfeitos. Por isso o Logger usa um caminho separado para gravar o log.

## Como o log sobrevive ao rollback

1. `Logger.error(...)` guarda a entrada em memória. Nada é gravado nesse momento.
2. `Logger.flush()` publica a entrada como `Log_Event__e`, com *Publish Immediately*.
3. O `LogEventTrigger` recebe o evento e grava o `Log__c` em outra transação.

Por isso o `flush()` fica no `finally`: ele publica o log mesmo quando o `catch` relança a exceção.

```apex
Savepoint sp = Database.setSavepoint();
try {
    // DML de negócio
} catch (Exception e) {
    Database.rollback(sp);
    Logger.error('MinhaClasse', e, recordId);
} finally {
    Logger.flush();
}
```

## O que foi validado na org

Roteiro executado na DevEd: a conta criada antes do rollback foi revertida, e o `Log__c` gravado antes do rollback continuou na org.

```apex
Savepoint sp = Database.setSavepoint();
insert new Account(Name = 'Probe Rollback');
Logger.error('RollbackProbe', 'Publicado antes do rollback', null);
Logger.flush();
Database.rollback(sp);
```

Depois do rollback, `SELECT Id FROM Account WHERE Name = 'Probe Rollback'` não retorna nada, e `SELECT Id FROM Log__c WHERE Source__c = 'RollbackProbe'` retorna um registro.

## Limites

- **Exceção não tratada:** se um erro derrubar a transação antes do `flush()`, o log se perde. O `try/catch` com `finally` no ponto de entrada evita isso. Não há como gravar nada depois de uma falha não tratada na mesma transação.
- **Publicações por transação:** o limite de chamadas de publicação é de 150 por transação. O Logger publica em lotes de 200 eventos por chamada.
- **Standard Volume:** o *Publish Immediately* depende do Standard Volume Platform Event. Há um comentário em um blog de terceiros sobre a aposentadoria dele, sem confirmação na documentação oficial. Se isso se confirmar, a abordagem precisa ser revista: o caminho alternativo é o savepoint com o `flush()` depois do rollback, que cobre só erros tratados.
