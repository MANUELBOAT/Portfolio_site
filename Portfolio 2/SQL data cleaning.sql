SELECT *
FROM layoffs;

-- what we are going to do through this data cleaning journey
-- 1. Remove duplicates
-- 2. Standardize the data
-- 3. Remove the null or bkank values
-- 4. Remove the columns

CREATE TABLE layoff_staging
LIKE layoffs;

SELECT * 
FROM layoff_staging;

INSERT layoff_staging
SELECT * 
FROM layoffs;

-- Finding duplicates 
SELECT *,
ROW_NUMBER() OVER(
PARTITION BY company, location, stage, funds_raised_millions, country, industry, total_laid_off, percentage_laid_off, `date`) AS row_num
FROM layoff_staging;

WITH duplicate_cte AS
(
SELECT *,
ROW_NUMBER() OVER(
PARTITION BY company, location, stage, funds_raised_millions, country, industry, total_laid_off, percentage_laid_off, `date`) AS row_num
FROM layoff_staging
)
SELECT * 
FROM duplicate_cte 
WHERE row_num > 1;

SELECT * 
FROM layoff_staging
WHERE company = 'Casper';

CREATE TABLE `layoff_staging2` (
  `company` text,
  `location` text,
  `industry` text,
  `total_laid_off` int DEFAULT NULL,
  `percentage_laid_off` text,
  `date` text,
  `stage` text,
  `country` text,
  `funds_raised_millions` int DEFAULT NULL,
  `row_num` INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

SELECT *
FROM layoff_staging2;

INSERT INTO layoff_staging2
SELECT *,
ROW_NUMBER() OVER(
PARTITION BY company, location, stage, funds_raised_millions, country, industry, total_laid_off, percentage_laid_off, `date`) AS row_num
FROM layoff_staging;

DELETE 
FROM layoff_staging2
WHERE row_num > 1;
;

SELECT *
FROM layoff_staging2;


-- STANDARDIZING DATA
SELECT company, Trim(company)
FROM layoff_staging2;

UPDATE layoff_staging2
SET company = TRIM(company);

SELECT DISTINCT industry
FROM layoff_staging2
ORDER BY 1;

SELECT * 
FROM layoff_staging2
WHERE industry LIKE 'Crypto%';

UPDATE layoff_staging2
SET industry = 'Crypto'
WHERE industry LIKE 'Crypto%';


SELECT DISTINCT country, TRIM(TRAILING '.' FROM country)
FROM layoff_staging2
ORDER BY 1;

UPDATE layoff_staging2
SET country = TRIM(TRAILING '.' FROM country)
WHERE country LIKE 'United States%';

SELECT `date`
FROM layoff_staging2; 

UPDATE layoff_staging2
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y');

ALTER TABLE layoff_staging2
MODIFY COLUMN `date` DATE;


-- Removing the blank and null columns
SELECT t1.industry, t2.industry
FROM layoff_staging2 t1
JOIN layoff_staging2 t2
	ON t1.company = t2.company
WHERE (t1.industry IS NULL OR t1.industry = '')
AND t2.industry IS NOT NULL;

UPDATE layoff_staging2 t2
SET industry = NULL
WHERE industry = '';

UPDATE layoff_staging2 t1
JOIN layoff_staging2 t2
	ON t1.company = t2.company
SET t1.industry = t2.industry 
WHERE t1.industry IS NULL 
AND t2.industry IS NOT NULL;

SELECT *
FROM layoff_staging2
;

ALTER TABLE layoff_staging2
DROP COLUMN row_num;

DELETE 
FROM layoff_staging2
WHERE total_laid_off IS NULl 
AND percentage_laid_off IS NULL;
