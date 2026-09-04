"use client";

import { Cloud, HardDrive } from "lucide-react";
import R2ConfigSection from "../settings/R2ConfigSection";

export default function AdminStorage() {
  return (
    <div className="space-y-4">
      <div>
        <h2 className="text-lg font-bold text-adm-text">云端存储</h2>
        <p className="mt-1 text-sm text-adm-text-secondary">
          使用 Cloudflare R2 保存上传文件；未启用 R2 时，文件会保存到容器持久化目录。
        </p>
      </div>

      <div className="flex items-center gap-3 rounded-xl border border-adm-border bg-adm-card p-4">
        <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-orange-500/10 text-orange-500">
          <Cloud className="h-5 w-5" />
        </div>
        <div className="min-w-0 flex-1">
          <div className="text-sm font-semibold text-adm-text">Cloudflare R2</div>
          <div className="mt-0.5 text-xs text-adm-text-tertiary">S3 兼容对象存储，适合图片、视频、音频和附件</div>
        </div>
        <HardDrive className="h-4 w-4 text-adm-text-tertiary" aria-label="支持本地存储回退" />
      </div>

      <R2ConfigSection />
    </div>
  );
}
