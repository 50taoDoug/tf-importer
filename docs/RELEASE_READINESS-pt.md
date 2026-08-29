# Prontidão de release

[English](RELEASE_READINESS.md)

## Objetivo

Este checklist prepara um candidato revisado sem autorizar tag, GitHub Release,
mudança de visibilidade, merge ou publicação. Mudanças de produto permanecem na
fonte privada autoritativa até serem sanitizadas e sincronizadas para um checkout
standalone limpo.

## Decisão da versão atual

O proprietário aprovou `v1.0.1` em 2026-08-29 para encerrar a Fase 1. O histórico
público sanitizado atual não contém uma tag de release, apesar de registros
privados descreverem uma tag em um histórico de publicação substituído. Não
recrie nem mova `v1.0.0` no histórico atual.

`VERSION`, `CITATION.cff` e o changelog estão alinhados em `1.0.1`. Crie a tag
anotada `v1.0.1` somente depois que o commit sincronizado exato passar por todos
os gates; em seguida, publique a GitHub Release correspondente sem mover a tag.

## Gates offline

Execute sem credenciais AWS:

```bash
make test
make ci
```

O CI deve aprovar testes, sintaxe Bash, ShellCheck, compilação Python, JSON,
formatação Terraform, proibição de apply, isolamento de credenciais, padrões de
arquivos rastreados e segredos, links Markdown, metadados de release, smoke test
de checkout limpo e whitespace do Git. Registre a contagem exata de testes; nunca
reutilize ou deduza resultados antigos.

## Sanitização e validação standalone

1. Execute a auditoria com a denylist privada sobre a fonte publicável e todo o
   histórico standalone alcançável.
2. Sincronize pelo script privado de publicação revisado.
3. Revise cada caminho alterado e confirme a ausência de documentação privada e
   dados de runtime.
4. Valide em um checkout standalone limpo, sem configuração AWS.
5. Confirme o commit standalone exato e uma execução bem-sucedida do CI.
6. Revise o histórico e os logs acessíveis do Actions antes de mudar a
   visibilidade.

Terraform gerado, state, planos, relatórios, inventários, pacotes Lambda, valores
SSM, credenciais, configuração local e identificadores privados nunca são
artefatos de release.

## Limite da aceitação AWS real

O CI offline não comprova descoberta real, comportamento do provider, paridade de
imports ou limpeza. Repita a aceitação controlada na AWS somente quando a mudança
afetar essas áreas e o proprietário autorizar separadamente conta, região, acesso
temporário, criação de recursos e limpeza. O `tf-importer` nunca executa
`terraform apply`.

Um plano aceito contém somente imports e zero ações de add, change ou destroy.

## Gate final de aprovação

Pare depois de apresentar o diff revisado, as evidências exatas de validação e os
riscos restantes. O proprietário deve aprovar separadamente cada merge, tag,
GitHub Release, mudança de visibilidade ou anúncio externo.
