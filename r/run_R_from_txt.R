# Detected R package dependencies: None detected
#!/usr/bin/env Rscript
# Wrapper generated from your R语言.txt
# Usage: Rscript run_R_from_txt.R <input_image_path> <model_dir>
args <- commandArgs(trailingOnly=TRUE)
if (length(args) < 2) {
  stop('Usage: Rscript run_R_from_txt.R <input_image_path> <model_dir>')
}
input_image <- args[1]
model_dir <- args[2]
model_path <- file.path(model_dir, 'model.rds')
if (!file.exists(model_path)) stop(paste('model.rds not found at', model_path))

# --- Begin original R code (from R语言.txt) ---
# The following block is the raw content of your R语言.txt. 
# It may require small edits to use 'input_image' and 'model_path' variables.
cat('--- start of embedded R code ---\n')

# ========== Logistic regression per class → imaging score (coef-based) → multi-ROC (train/test) → waterfall plots ==========
# 依赖：data.table, dplyr, stringr, pROC, broom, caret, ggplot2, glmnet
# install.packages(c("data.table","dplyr","stringr","pROC","broom","caret","ggplot2","glmnet"))

suppressPackageStartupMessages({
	library(data.table)
	library(dplyr)
	library(stringr)
	library(pROC)
	library(broom)
	library(caret)
	library(ggplot2)
	library(glmnet)
})
options(stringsAsFactors = FALSE)

# ---------- 路径配置 ----------
root_dir <- "F:/Basic-Seg-Experiment-main/Basic-Seg-Experiment-main/checkpoints/OCTnext/radiomics_results/filtered_by_roi/TTsplit_feature_matrices"
set.seed(2025)

# ---------- 工具函数 ----------
safe_read <- function(p) suppressWarnings(fread(p)) |> as.data.frame()
ensure_dir <- function(d){ if(!dir.exists(d)) dir.create(d, recursive=TRUE, showWarnings=FALSE) }

# ---------- 选择可用特征矩阵（优先 RF→LASSO→Spearman→Z_all） ----------
# 说明：本脚本的ROC来自“每一类的逻辑回归模型”；随机森林仅用于“特征选择”，不是预测模型。
pick_feature_mats <- function(one_dir) {
	candidates <- list(
		list(tr="X_train_rf_selected.csv", te="X_test_rf_selected.csv", tag="rf_selected"),
		list(tr="X_train_lasso_min.csv",  te="X_test_lasso_min.csv",  tag="lasso_min"),
		list(tr="X_train_lasso_1se.csv",  te="X_test_lasso_1se.csv",  tag="lasso_1se"),
		list(tr="X_train_spearman.csv",   te="X_test_spearman.csv",   tag="spearman_only"),
		list(tr="X_train_z_all.csv",      te="X_test_z_all.csv",      tag="z_all")
	)
	for (c in candidates) {
		tr <- file.path(one_dir, c$tr); te <- file.path(one_dir, c$te)
		if (!file.exists(tr) || !file.exists(te)) {
			message("[SKIP] 缺文件：", basename(one_dir), " → ", c$tag,
							" [missing_train=", !file.exists(tr), ", missing_test=", !file.exists(te), "]")
			next
		}
		xtr <- safe_read(tr); xte <- safe_read(te)
		has_y_tr <- "GroupResp" %in% names(xtr); has_y_te <- "GroupResp" %in% names(xte)
		n_feat_tr <- ncol(dplyr::select(xtr, where(is.numeric)))
		n_feat_te <- ncol(dplyr::select(xte, where(is.numeric)))
		if (has_y_tr && has_y_te && n_feat_tr >= 1 && n_feat_te >= 1) {
			message("[PICK] ", basename(one_dir), " → ", c$tag,
							" (numeric feats: tr=", n_feat_tr, ", te=", n_feat_te, ")")
			return(list(train=tr, test=te, tag=c$tag))
		} else {
			message("[SKIP] 有列但不合格：has_y_tr=", has_y_tr, ", has_y_te=", has_y_te,
							", n_feat_tr=", n_feat_tr, ", n_feat_te=", n_feat_te,
							" @ ", basename(one_dir))
		}
	}
	return(NULL)
}

# ---------- 影像分数（线性预测值）计算：coef 向量 × 特征矩阵 + 截距 ----------
compute_imaging_score <- function(coef_named_vec, df_feat) {
	beta0 <- unname(coef_named_vec["(Intercept)"])
	if (is.na(beta0)) beta0 <- 0
	feat_names <- setdiff(names(coef_named_vec), "(Intercept)")
	feats <- intersect(feat_names, colnames(df_feat))
	if (length(feats) == 0) return(rep(beta0, nrow(df_feat)))
	X <- as.matrix(df_feat[, feats, drop = FALSE])
	betas <- as.numeric(coef_named_vec[feats])
	drop(as.numeric(X %*% betas) + beta0)
}

# ---------- 保存瀑布图（PDF 优先，失败则 PNG） ----------
plot_score_bars <- function(df, score_col = "ImagingScore", label_col = "GroupResp",
														title_main, out_pdf, out_png) {
	if (!nrow(df)) { message("[SKIP] 瀑布图：数据为空"); return(invisible(NULL)) }
	df[[label_col]] <- factor(df[[label_col]], levels = c("NonResponder","Responder"))
	data <- df %>% arrange(.data[[score_col]]) %>% mutate(sample_id = dplyr::row_number())
	
	p <- ggplot(data, aes(x = sample_id, y = .data[[score_col]], fill = .data[[label_col]])) +
		geom_col(width = 1) +
		scale_fill_manual(
			name = "Group",
			values = c("NonResponder" = "blue", "Responder" = "orange"),
			labels = c("NonResponder (0)", "Responder (1)")
		) +
		labs(title = title_main, subtitle = "Samples ordered by ascending imaging score",
				 x = "Sample Index", y = "Imaging Score (Logit)") +
		theme_minimal(base_size = 12) +
		theme(
			legend.position = "bottom",
			legend.title = element_text(face = "bold"),
			axis.text.x = element_blank(),
			axis.ticks.x = element_blank(),
			panel.grid.major.x = element_blank(),
			panel.grid.minor.y = element_blank(),
			plot.title = element_text(hjust = 0.5, face = "bold", size = 16),
			plot.subtitle = element_text(hjust = 0.5, color = "gray40")
		)
	
	ok_pdf <- TRUE
	tryCatch({
		ggsave(out_pdf, plot = p, width = 10, height = 6, device = "pdf", dpi = 300)
		message("[OK] 瀑布图 PDF：", out_pdf)
	}, error = function(e) {
		ok_pdf <<- FALSE
		message("[WARN] PDF 保存失败 → 改存 PNG：", e$message)
	})
	if (!ok_pdf) {
		tryCatch({
			ggsave(out_png, plot = p, width = 10, height = 6, device = "png", dpi = 300)
			message("[OK] 瀑布图 PNG：", out_png)
		}, error = function(e) {
			message("[ERROR] 瀑布图保存失败：", e$message)
		})
	}
}

# ---------- Ridge 逻辑回归回退（确保可用系数） ----------
ridge_logit_fallback <- function(X_tr, y_tr) {
	x <- as.matrix(X_tr); y <- as.numeric(y_tr)
	cvfit <- cv.glmnet(x, y, family = "binomial", alpha = 0, nfolds = 5, type.measure = "deviance")
	cf_mat <- coef(cvfit, s = "lambda.min")
	coef_vec <- as.numeric(cf_mat)
	names(coef_vec) <- rownames(cf_mat) # "(Intercept)" + 特征名
	coef_vec
}

# ---------- 逻辑回归：拟合 + 影像分数 + 概率 + ROC + 导出 + 瀑布图 ----------
fit_logit_and_export <- function(one_dir, dataset_name) {
	sel <- pick_feature_mats(one_dir)
	if (is.null(sel)) { message("[SKIP] 无可用特征矩阵：", dataset_name); return(NULL) }
	
	xtr <- safe_read(sel$train)
	xte <- safe_read(sel$test)
	
	# --- 目标列存在性检查 ---
	if (!("GroupResp" %in% names(xtr) && "GroupResp" %in% names(xte))) {
		message("[SKIP] 缺少 GroupResp：", dataset_name); return(NULL)
	}
	
	# --- 规范化 GroupResp（兼容 0/1、yes/no/true/false/responder 等） ---
	normalize_resp <- function(v) {
		if (is.factor(v)) v <- as.character(v)
		if (is.numeric(v)) return(ifelse(v >= 0.5, "Responder", "NonResponder"))
		vv <- trimws(tolower(as.character(v)))
		pos <- c("1","yes","y","true","t","responder","respond","r","positive","pos")
		ifelse(vv %in% pos, "Responder", "NonResponder")
	}
	xtr$GroupResp <- normalize_resp(xtr$GroupResp)
	xte$GroupResp <- normalize_resp(xte$GroupResp)
	
	y_tr01 <- as.integer(factor(xtr$GroupResp, levels=c("NonResponder","Responder"))) - 1
	y_te01 <- as.integer(factor(xte$GroupResp, levels=c("NonResponder","Responder"))) - 1
	
	# --- 只保留真正的数值特征，且显式排除 GroupResp；并保证训练/测试列对齐 ---
	X_tr0 <- xtr %>% dplyr::select(where(is.numeric)) %>% dplyr::select(-dplyr::any_of("GroupResp"))
	X_te0 <- xte %>% dplyr::select(where(is.numeric)) %>% dplyr::select(-dplyr::any_of("GroupResp"))
	common_feats <- intersect(colnames(X_tr0), colnames(X_te0))
	X_tr0 <- X_tr0[, common_feats, drop = FALSE]
	X_te0 <- X_te0[, common_feats, drop = FALSE]
	
	message(sprintf("[INFO] 原始数值特征数：%d；对齐后：%d", ncol(xtr %>% dplyr::select(where(is.numeric))),
									length(common_feats)))
	
	if (ncol(X_tr0) == 0) { message("[SKIP] 训练集无数值特征：", dataset_name); return(NULL) }
	
	# --- 近零方差剔除 ---
	nzv <- sapply(X_tr0, function(v) sd(v, na.rm=TRUE) < 1e-10)
	if (any(nzv)) {
		message("[INFO] 近零方差剔除列数：", sum(nzv))
		X_tr0 <- X_tr0[, !nzv, drop=FALSE]; X_te0 <- X_te0[, !nzv, drop=FALSE]
	}
	if (ncol(X_tr0) == 0) { message("[SKIP] 近零方差剔除后无特征：", dataset_name); return(NULL) }
	
	# --- 完全线性相关剔除 ---
	flc <- try(findLinearCombos(as.matrix(X_tr0)), silent = TRUE)
	if (!inherits(flc, "try-error") && !is.null(flc$remove) && length(flc$remove) > 0) {
		message("[INFO] 线性相关剔除列数：", length(flc$remove))
		X_tr0 <- X_tr0[, -flc$remove, drop=FALSE]
		X_te0 <- X_te0[, -flc$remove, drop=FALSE]
	}
	if (ncol(X_tr0) == 0) { message("[SKIP] 线性相关剔除后无特征：", dataset_name); return(NULL) }
	
	df_tr_feat <- data.frame(X_tr0, check.names = TRUE)
	df_te_feat <- data.frame(X_te0, check.names = TRUE)
	df_tr <- data.frame(y = y_tr01, df_tr_feat, check.names = TRUE)
	df_te <- data.frame(y = y_te01, df_te_feat, check.names = TRUE)
	
	# ---- 拟合：先标准 glm，失败再 ridge 回退 ----
	used_model <- "glm"
	fit_glm <- try(glm(y ~ ., data = df_tr, family = binomial(), control = list(maxit=200)), silent = TRUE)
	
	if (inherits(fit_glm, "try-error") ||
			anyNA(coef(fit_glm)) ||
			length(coef(fit_glm)) <= 1) {
		message("[INFO] GLM 失败/系数异常，使用 Ridge 回退：", dataset_name)
		used_model <- "ridge_glmnet"
		coef_vec <- ridge_logit_fallback(df_tr_feat, df_tr$y)
		img_score_tr <- compute_imaging_score(coef_vec, df_tr_feat)
		img_score_te <- compute_imaging_score(coef_vec, df_te_feat)
	} else {
		coef_vec <- coef(fit_glm)
		img_score_tr <- as.numeric(predict(fit_glm, newdata = df_tr, type = "link"))
		img_score_te <- as.numeric(predict(fit_glm, newdata = df_te, type = "link"))
	}
	
	# 概率
	pred_prob_tr <- plogis(img_score_tr)
	pred_prob_te <- plogis(img_score_te)
	
	# 系数导出（统一写到各自目录）
	if (used_model == "glm") {
		coef_df <- broom::tidy(fit_glm) %>% mutate(dataset = dataset_name, tag = sel$tag, model = used_model)
	} else {
		coef_df <- data.frame(term = names(coef_vec), estimate = as.numeric(coef_vec),
													statistic = NA_real_, p.value = NA_real_,
													dataset = dataset_name, tag = sel$tag, model = used_model)
	}
	write.csv(coef_df, file.path(one_dir, "logit_coefficients.csv"), row.names = FALSE)
	
	# AUC + CI（允许失败）
	roc_tr <- try(pROC::roc(response = df_tr$y, predictor = pred_prob_tr, quiet = TRUE, levels = c(0,1)), silent = TRUE)
	roc_te <- try(pROC::roc(response = df_te$y, predictor = pred_prob_te, quiet = TRUE, levels = c(0,1)), silent = TRUE)
	auc_tr <- if (!inherits(roc_tr, "try-error")) as.numeric(pROC::auc(roc_tr)) else NA_real_
	auc_te <- if (!inherits(roc_te, "try-error")) as.numeric(pROC::auc(roc_te)) else NA_real_
	ci_tr  <- if (!inherits(roc_tr, "try-error")) as.numeric(pROC::ci.auc(roc_tr)) else c(NA,NA,NA)
	ci_te  <- if (!inherits(roc_te, "try-error")) as.numeric(pROC::ci.auc(roc_te)) else c(NA,NA,NA)
	
	# 预测与影像分数导出
	out_tr <- data.frame(GroupResp = xtr$GroupResp, PredProb = pred_prob_tr, ImagingScore = img_score_tr, df_tr_feat)
	out_te <- data.frame(GroupResp = xte$GroupResp, PredProb = pred_prob_te, ImagingScore = img_score_te, df_te_feat)
	write.csv(out_tr, file.path(one_dir, "predictions_train_with_scores.csv"), row.names = FALSE)
	write.csv(out_te, file.path(one_dir, "predictions_test_with_scores.csv"),  row.names = FALSE)
	
	# 公式文本（注明回退）
	sink(file.path(one_dir, "logit_formula.txt"))
	cat("Model:", used_model, "\n")
	cat("Logit(P) = Intercept + sum(beta_i * Xi)\n\n")
	print(data.frame(term = names(coef_vec), estimate = as.numeric(coef_vec)))
	sink()
	
	# 瀑布图保存（各自目录 plots/）
	plot_dir <- file.path(one_dir, "plots"); ensure_dir(plot_dir)
	wf_train <- data.frame(GroupResp = xtr$GroupResp, ImagingScore = img_score_tr)
	plot_score_bars(
		df = wf_train,
		score_col = "ImagingScore",
		label_col = "GroupResp",
		title_main = paste0("Imaging Scores (Waterfall) - Train - ", dataset_name, " [", sel$tag, "|", used_model, "]"),
		out_pdf = file.path(plot_dir, paste0("waterfall_train_", dataset_name, "_", sel$tag, "_", used_model, ".pdf")),
		out_png = file.path(plot_dir, paste0("waterfall_train_", dataset_name, "_", sel$tag, "_", used_model, ".png"))
	)
	wf_test <- data.frame(GroupResp = xte$GroupResp, ImagingScore = img_score_te)
	plot_score_bars(
		df = wf_test,
		score_col = "ImagingScore",
		label_col = "GroupResp",
		title_main = paste0("Imaging Scores (Waterfall) - Test - ", dataset_name, " [", sel$tag, "|", used_model, "]"),
		out_pdf = file.path(plot_dir, paste0("waterfall_test_", dataset_name, "_", sel$tag, "_", used_model, ".pdf")),
		out_png = file.path(plot_dir, paste0("waterfall_test_", dataset_name, "_", sel$tag, "_", used_model, ".png"))
	)
	
	list(
		dataset = dataset_name,
		tag     = paste0(sel$tag, "|", used_model),
		roc_tr  = if (!inherits(roc_tr, "try-error")) roc_tr else NULL,
		roc_te  = if (!inherits(roc_te, "try-error")) roc_te else NULL,
		auc_tr  = auc_tr, ci_tr = ci_tr,
		auc_te  = auc_te, ci_te = ci_te,
		nfeat   = ncol(df_tr) - 1,
		ntr     = nrow(df_tr),
		nte     = nrow(df_te)
	)
}

# ---------- 主流程：逐个数据集拟合 ----------
# 关键修复：取“子目录列表”，避免只拿到 root_dir 自身导致一个都没跑
all_dirs <- list.dirs(root_dir, full.names = TRUE, recursive = FALSE)
all_dirs <- all_dirs[all_dirs != root_dir]  # 去掉根目录自身
all_dirs <- all_dirs[dir.exists(all_dirs)]

if (length(all_dirs) == 0) {
	# 兜底：递归列出后剔除根目录本身，只保留“叶子目录”
	all_dirs <- list.dirs(root_dir, full.names = TRUE, recursive = TRUE)
	all_dirs <- all_dirs[all_dirs != root_dir]
	all_dirs <- all_dirs[vapply(all_dirs, function(p) length(list.files(p, pattern="^X_train_.*\\.csv$"))>0, logical(1))]
}

dataset_name_from_dir <- function(path) {
	bn <- basename(path)
	m <- str_match(bn, "radiomics_features_kept_overlays_([^/\\\\]+)")
	if (!is.na(m[1,2])) return(m[1,2])
	return(bn)
}

results <- list()
if (length(all_dirs) > 0) {
	message("[INFO] 将在以下目录建模：\n - ", paste(basename(all_dirs), collapse = "\n - "))
	for (d in all_dirs) {
		ds <- dataset_name_from_dir(d)
		message("[RUN] ", ds, "  @  ", d)
		res <- try(fit_logit_and_export(d, ds), silent = TRUE)
		if (!inherits(res, "try-error") && !is.null(res)) results[[ds]] <- res
	}
} else {
	message("[WARN] 未发现任何包含特征矩阵的子目录：", root_dir)
}

# ---------- 汇总表（即使没有结果也写出空表） ----------
summary_path <- file.path(root_dir, "logit_auc_summary.csv")
if (length(results) > 0) {
	sum_df <- do.call(rbind, lapply(results, function(r)
		data.frame(
			Dataset = r$dataset, Tag = r$tag,
			N_train = r$ntr, N_test = r$nte, N_feat = r$nfeat,
			AUC_train = r$auc_tr, CI_train_low = r$ci_tr[1], CI_train_high = r$ci_tr[3],
			AUC_test  = r$auc_te,  CI_test_low  = r$ci_te[1], CI_test_high  = r$ci_te[3]
		)
	))
	write.csv(sum_df, summary_path, row.names = FALSE)
	message("[OK] 汇总已写出：", summary_path)
} else {
	empty_df <- data.frame(
		Dataset = character(0), Tag = character(0),
		N_train = integer(0), N_test = integer(0), N_feat = integer(0),
		AUC_train = numeric(0), CI_train_low = numeric(0), CI_train_high = numeric(0),
		AUC_test = numeric(0),  CI_test_low  = numeric(0), CI_test_high  = numeric(0)
	)
	write.csv(empty_df, summary_path, row.names = FALSE)
	message("[INFO] 没有可用的大类：已写出空的 logit_auc_summary.csv；跳过 ROC 绘图。")
}

# ---------- 画多重 ROC（仅当至少存在一条可画曲线时；来自“各类的逻辑回归模型”） ----------
if (length(results) > 0) {
	rocs_tr <- Filter(Negate(is.null), lapply(results, `[[`, "roc_tr"))
	rocs_te <- Filter(Negate(is.null), lapply(results, `[[`, "roc_te"))
	
	# 训练
	if (length(rocs_tr) > 0) {
		pdf(file.path(root_dir, "MultiROC_train.pdf"), width = 7, height = 6)
		first <- TRUE
		cols <- grDevices::rainbow(max(6, length(rocs_tr)))
		i <- 1; legend_items <- c()
		for (nm in names(results)) {
			r <- results[[nm]]
			if (is.null(r$roc_tr)) next
			if (first) {
				plot.roc(r$roc_tr, col = cols[i], lwd = 2, legacy.axes = TRUE, main = "Multi-ROC (Train) — Logistic per class")
				first <- FALSE
			} else {
				plot.roc(r$roc_tr, col = cols[i], lwd = 2, add = TRUE, legacy.axes = TRUE)
			}
			legend_items <- c(legend_items, sprintf("%s (AUC=%.3f)", nm, r$auc_tr))
			i <- i + 1
		}
		if (length(legend_items) > 0) legend("bottomright", legend = legend_items, col = cols[seq_along(legend_items)], lwd = 2, cex = 0.9)
		dev.off()
		message("[OK] 训练集多重 ROC 已保存：", file.path(root_dir, "MultiROC_train.pdf"))
	} else {
		message("[INFO] 无可画的训练 ROC 曲线，跳过 MultiROC_train.pdf")
	}
	
	# 测试
	if (length(rocs_te) > 0) {
		pdf(file.path(root_dir, "MultiROC_test.pdf"), width = 7, height = 6)
		first <- TRUE
		cols <- grDevices::rainbow(max(6, length(rocs_te)))
		i <- 1; legend_items <- c()
		for (nm in names(results)) {
			r <- results[[nm]]
			if (is.null(r$roc_te)) next
			if (first) {
				plot.roc(r$roc_te, col = cols[i], lwd = 2, legacy.axes = TRUE, main = "Multi-ROC (Test) — Logistic per class")
				first <- FALSE
			} else {
				plot.roc(r$roc_te, col = cols[i], lwd = 2, add = TRUE, legacy.axes = TRUE)
			}
			legend_items <- c(legend_items, sprintf("%s (AUC=%.3f)", nm, r$auc_te))
			i <- i + 1
		}
		if (length(legend_items) > 0) legend("bottomright", legend = legend_items, col = cols[seq_along(legend_items)], lwd = 2, cex = 0.9)
		dev.off()
		message("[OK] 测试集多重 ROC 已保存：", file.path(root_dir, "MultiROC_test.pdf"))
	} else {
		message("[INFO] 无可画的测试 ROC 曲线，跳过 MultiROC_test.pdf")
	}
}

# ---------- 收尾自检：列出所有生成的图片 ----------
message("\n[POST-CHECK] 搜索已生成的图文件...")
all_imgs <- list.files(root_dir, pattern = "(waterfall_.*\\.(pdf|png)|MultiROC_.*\\.pdf)$",
											 recursive = TRUE, full.names = TRUE)
if (length(all_imgs) == 0) {
	message("[POST-CHECK] 仍未找到任何图片，请检查上方日志中 [SKIP]/[INFO] 的具体原因（如缺 GroupResp、无数值特征、样本量或标签单一等）。")
} else {
	message("[POST-CHECK] 找到 ", length(all_imgs), " 个图文件：")
	for (f in all_imgs) message(" - ", f)
}

message("\n[ALL DONE] 逐类逻辑（必要时回退 Ridge）建模、影像分数、瀑布图(双格式)与多重 ROC（均来自逻辑回归）已完成。")

# ========= SHAP on TEST set (kernelshap + shapviz) =========
suppressPackageStartupMessages({
	library(dplyr)
	library(caret)       # findLinearCombos
	library(kernelshap)  # Kernel SHAP
	library(shapviz)     # 可视化
	library(ggplot2)
})

# --- 工具：把响应转 0/1 ---
normalize_resp01 <- function(v) {
	if (is.factor(v)) v <- as.character(v)
	if (is.numeric(v)) return(as.integer(v >= 0.5))
	vv <- trimws(tolower(as.character(v)))
	pos <- c("1","yes","y","true","t","responder","respond","r","positive","pos","阳性","应答")
	as.integer(vv %in% pos)
}

# --- 训练/测试特征对齐 + 近零方差 + 线性相关 ---
prep_xy_for_model <- function(xtr, xte){
	y_tr <- normalize_resp01(xtr$GroupResp)
	y_te <- normalize_resp01(xte$GroupResp)
	X_tr0 <- xtr %>% dplyr::select(where(is.numeric)) %>% dplyr::select(-dplyr::any_of("GroupResp"))
	X_te0 <- xte %>% dplyr::select(where(is.numeric)) %>% dplyr::select(-dplyr::any_of("GroupResp"))
	common_feats <- intersect(colnames(X_tr0), colnames(X_te0))
	X_tr0 <- X_tr0[, common_feats, drop=FALSE]
	X_te0 <- X_te0[, common_feats, drop=FALSE]
	nzv <- sapply(X_tr0, function(v) sd(v, na.rm=TRUE) < 1e-10)
	if (any(nzv)) { X_tr0 <- X_tr0[, !nzv, drop=FALSE]; X_te0 <- X_te0[, !nzv, drop=FALSE] }
	flc <- try(findLinearCombos(as.matrix(X_tr0)), silent = TRUE)
	if (!inherits(flc, "try-error") && !is.null(flc$remove) && length(flc$remove)>0){
		X_tr0 <- X_tr0[, -flc$remove, drop=FALSE]; X_te0 <- X_te0[, -flc$remove, drop=FALSE]
	}
	list(X_tr = data.frame(X_tr0, check.names=TRUE),
			 X_te = data.frame(X_te0, check.names=TRUE),
			 y_tr = y_tr, y_te = y_te)
}

# --- 拟合：先 glm，失败回退 ridge (cv.glmnet, alpha=0) ---
fit_for_shap <- function(X_tr, y_tr){
	used <- "glm"
	df_tr <- data.frame(y = y_tr, X_tr, check.names = TRUE)
	fit_glm <- try(glm(y ~ ., data=df_tr, family=binomial(), control=list(maxit=200)), silent=TRUE)
	if (inherits(fit_glm,"try-error") || anyNA(coef(fit_glm)) || length(coef(fit_glm))<=1){
		used <- "ridge_glmnet"
		cvfit <- glmnet::cv.glmnet(as.matrix(X_tr), y_tr, family="binomial", alpha=0, nfolds=5, type.measure="deviance")
		return(list(model=cvfit, type=used))
	} else {
		return(list(model=fit_glm, type=used))
	}
}

# --- 统一预测函数：返回正类概率 ---
pred_fun_generic <- function(mod, newdata, model_type){
	if (model_type == "glm") {
		as.numeric(predict(mod, newdata = as.data.frame(newdata), type = "response"))
	} else if (model_type == "ridge_glmnet") {
		as.numeric(predict(mod, newx = as.matrix(newdata), s = "lambda.min", type = "response"))
	} else stop("Unknown model_type: ", model_type)
}

# --- 对单个目录(one_dir)做：测试集 SHAP + 每类取 1 个局部解释样本 ---
compute_shap_for_dir <- function(one_dir, max_bg = 200, max_test = 200){
	sel <- pick_feature_mats(one_dir)              # 复用你上面已有的函数
	if (is.null(sel)) { message("[SHAP][SKIP] 无可用特征矩阵：", one_dir); return(invisible(NULL)) }
	xtr <- safe_read(sel$train); xte <- safe_read(sel$test)
	stopifnot("GroupResp" %in% names(xtr), "GroupResp" %in% names(xte))
	
	pp <- prep_xy_for_model(xtr, xte)
	if (ncol(pp$X_tr) == 0L) { message("[SHAP][SKIP] 无有效数值特征：", one_dir); return(invisible(NULL)) }
	
	fit <- fit_for_shap(pp$X_tr, pp$y_tr)
	used_model <- fit$type
	
	# 背景集（训练集抽样，控制规模）
	bg_idx <- seq_len(nrow(pp$X_tr))
	if (length(bg_idx) > max_bg) bg_idx <- sample(bg_idx, max_bg)
	bg_X <- pp$X_tr[bg_idx, , drop=FALSE]
	
	# ---- 关键改动：测试集子样本需包含“0类和1类”各 1 个 ----
	all_idx <- seq_len(nrow(pp$X_te))
	idx0_full <- which(pp$y_te == 0)
	idx1_full <- which(pp$y_te == 1)
	
	if (length(idx0_full) == 0L || length(idx1_full) == 0L) {
		# 极端：测试集单一类别 → 就随机取两个做演示
		warning("[SHAP] 测试集只含单一类别，局部解释无法做到‘各类取一’；将随机取两例。")
		te_idx <- if (length(all_idx) > max_test) sample(all_idx, max_test) else all_idx
		class_note <- rep(NA_integer_, length(te_idx))
		exemplar_rows <- head(seq_along(te_idx), 2)  # PDF 里仍画前两例
	} else {
		idx0 <- sample(idx0_full, 1)
		idx1 <- sample(idx1_full, 1)
		pool <- setdiff(all_idx, c(idx0, idx1))
		extra_need <- max(0, max_test - 2)
		extra <- if (length(pool) > extra_need) sample(pool, extra_need) else pool
		te_idx <- unique(c(idx0, idx1, extra))
		# 确保“前两行”就是两类各 1 例
		# te_idx 的第1个对应 y_te==0，第2个对应 y_te==1
		if (!(pp$y_te[te_idx[1]] == 0 && pp$y_te[te_idx[2]] == 1)) {
			# 如顺序相反就调换
			if (pp$y_te[te_idx[1]] == 1 && pp$y_te[te_idx[2]] == 0) te_idx[1:2] <- te_idx[2:1]
			else {
				# 兜底：强行把第1个换成 0 类、第2个换成 1 类
				te_idx[1] <- idx0; te_idx[2] <- idx1
			}
		}
		class_note <- pp$y_te[te_idx]
		exemplar_rows <- c(1, 2)  # 解释这两个
	}
	
	X_test_sub <- pp$X_te[te_idx, , drop=FALSE]
	y_test_sub <- pp$y_te[te_idx]
	
	# 计算 Kernel SHAP（预测函数返回概率）
	ks <- kernelshap(
		object   = list(model = fit$model, type = used_model),
		X        = X_test_sub,
		bg_X     = bg_X,
		pred_fun = function(obj, newdata) pred_fun_generic(obj$model, newdata, obj$type)
	)
	
	# shapviz 对象（对齐列顺序）
	Xviz <- X_test_sub[, colnames(ks$S), drop=FALSE]
	sv   <- shapviz(ks, X = Xviz)
	
	# 预测概率（用于标题展示）
	preds <- pred_fun_generic(fit$model, Xviz, used_model)
	cls_lab <- ifelse(y_test_sub == 1, "Responder (1)", "NonResponder (0)")
	
	# 输出目录与标记
	shap_dir <- file.path(one_dir, "SHAP_test"); dir.create(shap_dir, showWarnings=FALSE, recursive=TRUE)
	tag <- paste0(sel$tag, "_", used_model)
	
	# 1) 全局重要性（bar）
	pdf(file.path(shap_dir, paste0("SHAP_Feature_Importance_bar_", tag, ".pdf")), width=8, height=6)
	print(sv_importance(sv, kind="bar") +
					ggplot2::theme_minimal(base_size=12) +
					ggplot2::labs(title = paste("Feature Importance (Mean |SHAP|) —", tag),
												x="Mean |SHAP|", y="Feature"))
	dev.off()
	
	# 2) 蜂群图（bee）
	pdf(file.path(shap_dir, paste0("SHAP_BeeSwarm_", tag, ".pdf")), width=9, height=7)
	print(sv_importance(sv, kind="bee") +
					ggplot2::theme_minimal(base_size=12) +
					ggplot2::labs(title = paste("SHAP Value Distribution (Bee Swarm) —", tag),
												x="SHAP value", y="Feature"))
	dev.off()
	
	# 3) 前 3 特征依赖
	imp <- colMeans(abs(ks$S), na.rm = TRUE)
	topk <- names(sort(imp, decreasing=TRUE))[seq_len(min(3, length(imp)))]
	for (feat in topk){
		pdf(file.path(shap_dir, paste0("SHAP_Dependence_", feat, "_", tag, ".pdf")), width=6, height=6)
		print(sv_dependence(sv, feature = feat, v = feat, jitter_width = 0.2) +
						ggplot2::labs(title = paste("SHAP Dependence:", feat), color = feat))
		dev.off()
	}
	
	# 4) 局部解释：每类 1 例（按我们放到前两行的示例）
	# Waterfall
	pdf(file.path(shap_dir, paste0("SHAP_Waterfall_two_classes_", tag, ".pdf")), width=9, height=6)
	for (rid in exemplar_rows) {
		ttl <- sprintf("Waterfall — row %d | %s | pred=%.3f", rid, cls_lab[rid], preds[rid])
		print(sv_waterfall(sv, row_id = rid) + ggplot2::labs(title = ttl))
	}
	dev.off()
	# Force
	pdf(file.path(shap_dir, paste0("SHAP_Force_two_classes_", tag, ".pdf")), width=10, height=6)
	for (rid in exemplar_rows) {
		ttl <- sprintf("Force — row %d | %s | pred=%.3f", rid, cls_lab[rid], preds[rid])
		print(sv_force(sv, row_id = rid) + ggplot2::labs(title = ttl))
	}
	dev.off()
	
	# 记录样本信息（便于复现）
	info <- data.frame(
		row_id_in_pdf = exemplar_rows,
		te_global_index = te_idx[exemplar_rows],
		class = cls_lab[exemplar_rows],
		pred_prob = preds[exemplar_rows]
	)
	write.csv(info, file.path(shap_dir, paste0("explained_two_examples_", tag, ".csv")), row.names = FALSE)
	
	message(sprintf("[SHAP][OK] %s | 模型=%s | 背景=%d | 测试=%d | 解释样本=两类各 1",
									shap_dir, used_model, nrow(bg_X), nrow(X_test_sub)))
	invisible(list(sv=sv, ks=ks, used=used_model, bg_n=nrow(bg_X), test_n=nrow(X_test_sub)))
}

# === 批量对 all_dirs 运行（你前面脚本里已经有 all_dirs 了）===
if (exists("all_dirs") && length(all_dirs) > 0){
	for (d in all_dirs) {
		message("[SHAP][RUN] ", d)
		try(compute_shap_for_dir(d, max_bg = 200, max_test = 200), silent = FALSE)
	}
} else {
	message("[SHAP][INFO] 未检测到可用子目录 all_dirs；也可手动： compute_shap_for_dir('.../radiomics_features_kept_overlays_IRF.filtered')")
}


cat('\n--- end of embedded R code ---\n')
