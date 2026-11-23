-- Acompanha a renomeação das pastas no ClickUp ("ST 01 - AOI" virou "AOI",
-- "Opera Tingui" virou "Ópera Tingui"), para a biblioteca de plantas voltar a
-- casar pelo nome. Vistorias antigas não são mexidas (as assinadas ficam congeladas).
-- Pode ser rodado mais de uma vez sem problema.

update public.plantas set predio = 'AOI'          where predio = 'ST 01 - AOI';
update public.plantas set predio = 'Ópera Tingui' where predio = 'Opera Tingui';
