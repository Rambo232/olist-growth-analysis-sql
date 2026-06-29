# Why Did Olist's Growth Stall? An E-Commerce Data Investigation

**[English](README.md) | [Русский](#почему-рост-olist-остановился-расследование-на-данных)**


## The Question

Olist's monthly revenue climbed steadily through 2017, peaked around the
November 2017 Black Friday surge, and then... flattened. By mid-2018 growth
had stalled even though new customers kept arriving every month. This
project investigates why, using SQL on Olist's public Brazilian e-commerce
dataset (~100k orders, ~96k customers, ~3k sellers, 2016–2018).

## The Investigation

### 1. Ruling out a measurement artifact

First check: is the "stagnation" real, or just an artifact of an incomplete
data export? Delivered-order share stays at 97–99% through August 2018,
then drops to near-zero for September/October — meaning the dataset was
extracted in early September 2018, and anything after August is incomplete
by design, not a business signal.
→ Analysis window capped at August 2018.
*(`sql/01_data_validation.sql`)*

### 2. Following the retention thread

With growth flat despite new signups, the obvious next question is
retention. A first pass at cohort retention came back around **5.4%** in
month one — until checking cohort sizes showed two single-customer cohorts
(Sep and Dec 2016) carrying the same weight in a simple average as cohorts
of 7,000+ people. Switching to a size-weighted average and excluding
cohorts under 50 customers gave a very different, far more sobering number:
**0.45% retention in month one.**
*(`sql/02_cohort_retention.sql`)*

### 3. Stress-testing the "0% repeat customers" hypothesis

A natural follow-up: does literally nobody come back? Running a frequency
distribution at the real-person level (not the per-order ID, which resets
on every single order) shows **97.0% of customers buy exactly once — but
3.0% (2,801 people) do come back**, one of them 15 times. Olist isn't a
pure one-and-done marketplace; it has a small, measurable loyal tail
buried inside an otherwise leaky funnel.
*(`sql/07_rfm_segmentation.sql`)*

### 4. Where the growth actually comes from

If retention isn't driving growth, acquisition is. New-customer counts
jump sharply around November 2017 (Brazil's Black Friday) and plateau at
6,000–6,500/month through 2018 — a ceiling on current acquisition
channels, not a retention failure.
*(`sql/03_revenue_growth.sql`)*

### 5. Looking for where the business can actually act

- **Category economics** — freight eats 20–25% of item price for
  furniture/home categories, vs. **4.4%** for computers: a 5x gap in
  logistics burden between categories with comparable order volumes.
- **Seller concentration** — the market is highly fragmented; the single
  largest seller holds under **2%** market share, so there's no
  single-vendor dependency risk.
- **Delivery time vs. category** — office furniture takes ~21 days to
  deliver, and customers tolerate it (0.08% cancellation), vs. ~12–13 days
  for electronics and beauty products.

*(`sql/04_category_analysis.sql`, `sql/05_seller_performance.sql`,
`sql/06_logistics_sla.sql`)*

## What This Means For The Business

- **Retention-focused spend is the wrong lever here.** The model is
  fundamentally acquisition-driven, and budget should follow that reality
  (lead generation, AOV growth, cross-sell within 72 hours of purchase)
  rather than chasing a repeat-purchase rate the product/category mix
  doesn't support.
- **Freight pricing could be rebalanced by category** instead of flat-rated,
  given the 5x spread in logistics cost share between categories.
- **The loyal 3% tail (RFM "Champion" segment) is small but real**, and
  worth a dedicated re-engagement flow rather than being averaged away
  into "nobody returns."

## On Methodology

Every claim above is backed by a query in `/sql`, and several of the
headline numbers only survived because an earlier, simpler version of the
query was wrong:

- **`customer_id` is a transaction ID, not a person ID.** It resets on
  every order. Grouping cohorts by it would show ~0% retention by
  construction, regardless of real behaviour. Switched to
  `customer_unique_id` throughout.
- **A plain `AVG()` over cohort retention rates let single-customer
  cohorts distort the headline number by ~10x.** Switched to a
  size-weighted average and a minimum cohort size of 50.
- **Suspected `freight_value` was duplicated across multi-item orders.**
  Tested the hypothesis at three levels of granularity (order, order +
  seller, order + product) before concluding it wasn't true — and kept
  the simpler, originally-correct query rather than "fixing" something
  that wasn't broken.
- **Cross-checked headline findings against an independently generated AI
  analysis of the same dataset.** One of its central claims — *"100% of
  customers are one-time buyers"* — turned out to be flatly contradicted
  by the data (see step 3 above). A specific seller's claimed order count
  in that same analysis was also off by ~8%. Both were caught and
  corrected before being included here.
- **Cross-checked a second external claim**, from public Kaggle
  discussion of this dataset, that retention varies sharply by
  geography — São Paulo at a "record low" ~6%, remote states like
  Rondônia above 10%. The real numbers are far more modest: São Paulo's
  repeat rate (3.14%) sits right at the platform average, not below it,
  and Rondônia — the most remote state with enough volume to measure
  reliably — is higher, but only at 4.33%, nowhere near the claimed
  10%+.

## Tech Stack

MySQL 8.0+ — CTEs, window functions, recursive CTEs (calendar gap-filling),
conditional aggregation.

## Repository Structure

```
sql/
  01_data_validation.sql      sanity checks before trusting any number above
  02_cohort_retention.sql     weighted retention by cohort month
  03_revenue_growth.sql       month-over-month revenue, gap-filled calendar
  04_category_analysis.sql    revenue, freight share, AOV by category
  05_seller_performance.sql   cancellation rate, market concentration
  06_logistics_sla.sql        delivery time vs. cancellation by category
  07_rfm_segmentation.sql     customer-level recency/frequency/monetary segments
```

## Possible Extensions

- Year-over-year comparison to strip out seasonality (Black Friday,
  December slowdown) from the month-over-month view.
- Seller-level join between delivery time and order volume to test
  whether faster sellers are rewarded with more orders.






## Почему рост Olist остановился? Расследование на данных

[⬆ Back to top](#why-did-olists-growth-stall-an-e-commerce-data-investigation)

### Вопрос

Месячная выручка Olist стабильно росла в течение 2017 года, достигла пика
на волне Чёрной пятницы в ноябре 2017, а затем... вышла на плато. К
середине 2018 рост практически остановился, хотя новые клиенты продолжали
приходить каждый месяц. Этот проект разбирается в причинах с помощью SQL
на публичном датасете бразильского e-commerce Olist (~100 тыс. заказов,
~96 тыс. клиентов, ~3 тыс. продавцов, 2016–2018).


## Расследование

### 1. Исключаем артефакт измерения

Первая проверка: реальна ли «стагнация», или это просто артефакт неполной
выгрузки данных? Доля доставленных заказов держится на уровне 97–99% до
августа 2018, после чего падает почти до нуля в сентябре/октябре — значит
выгрузка датасета произошла в начале сентября 2018, и всё после августа
неполно по построению, а не сигнал о бизнесе.
→ Период анализа ограничен августом 2018 включительно.
*(`sql/01_data_validation.sql`)*

### 2. Идём по следу retention

Если рост стоит на месте при постоянном притоке новых клиентов, логичный
следующий вопрос — удержание. Первый расчёт когортного retention дал
около **5.4%** в первый месяц — пока проверка размеров когорт не
показала, что две когорты по одному человеку (сентябрь и декабрь 2016)
влияют на простое среднее так же, как когорты по 7000+ людей. Переход на
взвешенное по размеру среднее и исключение когорт младше 50 человек дал
совсем другую, куда более тревожную цифру: **0.45% retention в первый
месяц**.
*(`sql/02_cohort_retention.sql`)*

### 3. Проверяем гипотезу «0% повторных клиентов» на прочность

Естественный следующий вопрос: правда ли вообще никто не возвращается?
Распределение частоты покупок на уровне реального человека (не ID
заказа, который создаётся заново на каждый заказ) показывает, что
**97.0% клиентов покупают ровно один раз — но 3.0% (2801 человек)
возвращаются**, один из них — 15 раз. Olist не чистая модель «купил и
ушёл навсегда»; внутри в целом дырявой воронки есть небольшой, измеримый
лояльный хвост.
*(`sql/07_rfm_segmentation.sql`)*

### 4. Откуда реально берётся рост

Если рост не держится на удержании — значит держится на привлечении.
Число новых клиентов резко скачет в ноябре 2017 (бразильская Чёрная
пятница) и выходит на плато 6000–6500/месяц в течение 2018 — это потолок
текущих каналов привлечения, а не провал удержания.
*(`sql/03_revenue_growth.sql`)*

### 5. Ищем, где бизнес реально может действовать

- **Экономика категорий** — доставка съедает 20–25% цены товара для
  мебели/дома, против **4.4%** для компьютеров: пятикратный разрыв в
  логистической нагрузке между категориями со сравнимым объёмом заказов.
- **Концентрация продавцов** — рынок сильно фрагментирован; крупнейший
  продавец держит менее **2%** доли рынка, системного риска зависимости
  от одного поставщика нет.
- **Срок доставки vs категория** — офисная мебель доставляется ~21 день
  (клиенты терпят: 0.08% отмен), против ~12–13 дней для электроники и
  косметики.

*(`sql/04_category_analysis.sql`, `sql/05_seller_performance.sql`,
`sql/06_logistics_sla.sql`)*

## Что это значит для бизнеса

- **Бюджет на удержание здесь — неверный рычаг.** Модель бизнеса
  фундаментально построена на привлечении, и бюджет должен следовать
  этой реальности (лидогенерация, рост среднего чека, cross-sell в
  первые 72 часа после покупки), а не гнаться за показателем повторных
  покупок, который не поддерживается товарной матрицей.
- **Тариф на доставку можно пересмотреть по категориям** вместо единой
  ставки, учитывая пятикратный разброс доли логистики.
- **Лояльный хвост в 3% (сегмент «Champion» в RFM) мал, но реален**, и
  заслуживает отдельного сценария повторного вовлечения, а не
  «усреднения в ноль».

## О методологии

Каждое утверждение выше подтверждено запросом в `/sql`, и несколько
ключевых цифр выжили только потому что более ранняя, простая версия
запроса оказалась неверной:

- **`customer_id` в таблице заказов — это ID транзакции, не человека.**
  Он создаётся заново при каждом заказе. Группировка когорт по нему
  показала бы ~0% retention по построению, независимо от реального
  поведения. Везде использован `customer_unique_id`.
- **Простой `AVG()` по проценту retention когорт позволил микро-когортам
  искажать итоговую цифру в ~10 раз.** Перешёл на взвешенное по размеру
  среднее и минимальный размер когорты 50 человек.
- **Подозревал дублирование `freight_value` в многотоварных заказах.**
  Проверил гипотезу на трёх уровнях гранулярности (заказ, заказ+продавец,
  заказ+товар) прежде чем сделать вывод что это не так — и оставил более
  простой, изначально верный запрос вместо «исправления» того, что не
  было сломано.
- **Сверил ключевые находки с независимо сгенерированным AI-анализом
  того же датасета.** Одно из его центральных утверждений — *«100%
  клиентов совершают разовые заказы»* — прямо противоречит данным (см.
  пункт 3 выше). Заявленное количество заказов у конкретного продавца в
  том же анализе тоже оказалось неверным, разница ~8%. Обе ошибки
  найдены и исправлены до включения в этот проект.
- **Сверил второе внешнее утверждение** из публичного обсуждения этого
  датасета на Kaggle — что retention резко различается по географии:
  Сан-Паулу с «рекордно низким» ~6%, отдалённые штаты типа Rondônia выше
  10%. Реальные цифры куда скромнее: retention Сан-Паулу (3.14%) —
  практически средний показатель по платформе, не ниже него, а
  Rondônia — самый отдалённый штат с достаточным объёмом для измерения —
  выше, но всего 4.33%, далеко от заявленных 10%+.

## Стек

MySQL 8.0+ — CTE, оконные функции, рекурсивные CTE (заполнение
календарных пропусков), условная агрегация.

## Структура репозитория

```
sql/
  01_data_validation.sql      проверки гипотез перед тем как доверять цифрам
  02_cohort_retention.sql     взвешенный retention по месяцу когорты
  03_revenue_growth.sql       рост выручки месяц к месяцу, заполненный календарь
  04_category_analysis.sql    выручка, доля доставки, средний чек по категориям
  05_seller_performance.sql   процент отмен, концентрация рынка
  06_logistics_sla.sql        срок доставки vs отмены по категориям
  07_rfm_segmentation.sql     RFM-сегменты на уровне реального покупателя
```

## Возможные продолжения

- Сравнение год-к-году для исключения сезонности (Чёрная пятница,
  декабрьское замедление) из помесячного ряда.
- Связка продавцов и срока доставки на уровне seller_id — проверить,
  получают ли более быстрые продавцы больше заказов.




**[English](README.md) | [Русский](#почему-рост-olist-остановился-расследование-на-данных)**
