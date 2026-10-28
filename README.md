# VAI-PARA-O-COMERCIAL-DEPOIS-VOLTA-PARA-O-FILME COMERCIAL CÍCLICO PARA OBS STUDIO

Este script alterna continuamente, sem horários fixos:
1. Mantém a cena do filme no ar pelo número de minutos configurado.
2. Troca para a cena do comercial.
3. Detecta automaticamente o fim da fonte de mídia contida nessa cena.
4. Volta ao filme e começa a contagem novamente.

INSTALAÇÃO / ATUALIZAÇÃO
1. No OBS, abra Ferramentas > Scripts.
2. Remova a versão antiga do script (botão -).
3. Clique em + e selecione comercial_ciclo.lua desta versão.
4. Configure os nomes exatos das cenas do filme e comercial e os minutos.

IMPORTANTE
- O vídeo do comercial precisa ser uma fonte dentro da cena do comercial.
- Desative Repetir/Loop na fonte de mídia para que ela emita o evento de término.
- O script detecta as fontes diretamente contidas na cena do comercial.
- Deixe o OBS aberto e a cena do filme no ar para iniciar a contagem.
- Usa a transição padrão do OBS.detalhe:funciona no obs 31 .A cena do intervalo tem que ser midia
