"use client";

import { useEffect, useMemo, useState } from "react";
import {
  AlertTriangle,
  Check,
  Cloud,
  ExternalLink,
  Eye,
  EyeOff,
  Loader2,
  Save,
} from "lucide-react";
import { apiFetch } from "@/lib/api-fetch";

interface R2Form {
  enabled: boolean;
  accountId: string;
  accessKeyId: string;
  secretAccessKey: string;
  bucket: string;
  publicDomain: string;
  path: string;
}

const EMPTY_FORM: R2Form = {
  enabled: false,
  accountId: "",
  accessKeyId: "",
  secretAccessKey: "",
  bucket: "",
  publicDomain: "",
  path: "",
};

export default function R2ConfigSection() {
  const [form, setForm] = useState<R2Form>(EMPTY_FORM);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [testing, setTesting] = useState(false);
  const [showSecret, setShowSecret] = useState(false);
  const [notice, setNotice] = useState<{ type: "success" | "error"; text: string } | null>(null);

  useEffect(() => {
    apiFetch("/settings/r2-config")
      .then(async (res) => {
        if (!res.ok) throw new Error("读取 R2 配置失败");
        const data = await res.json();
        setForm({
          enabled: !!data.r2Enabled,
          accountId: data.r2AccountId || "",
          accessKeyId: data.r2AccessKeyId || "",
          secretAccessKey: data.r2SecretAccessKey || "",
          bucket: data.r2Bucket || "",
          publicDomain: data.r2PublicDomain || "",
          path: data.r2Path || "",
        });
      })
      .catch((err) => setNotice({ type: "error", text: err.message || "读取配置失败" }))
      .finally(() => setLoading(false));
  }, []);

  const endpoint = useMemo(
    () => (form.accountId.trim() ? `https://${form.accountId.trim()}.r2.cloudflarestorage.com` : "填写 Account ID 后自动生成"),
    [form.accountId]
  );

  const update = (key: keyof R2Form, value: string | boolean) => {
    setForm((current) => ({ ...current, [key]: value }));
    setNotice(null);
  };

  const handleSave = async () => {
    setSaving(true);
    setNotice(null);
    try {
      const res = await apiFetch("/settings", {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          r2Enabled: form.enabled,
          r2AccountId: form.accountId,
          r2AccessKeyId: form.accessKeyId,
          r2SecretAccessKey: form.secretAccessKey,
          r2Bucket: form.bucket,
          r2PublicDomain: form.publicDomain,
          r2Path: form.path,
        }),
      });
      if (!res.ok) {
        const data = await res.json().catch(() => null);
        throw new Error(data?.message || "保存失败");
      }
      setNotice({ type: "success", text: "Cloudflare R2 配置已保存" });
    } catch (err: any) {
      setNotice({ type: "error", text: err.message || "保存失败" });
    } finally {
      setSaving(false);
    }
  };

  const handleTest = async () => {
    setTesting(true);
    setNotice(null);
    try {
      const res = await apiFetch("/upload/test-r2", { method: "POST" });
      const data = await res.json().catch(() => null);
      if (!res.ok || !data?.success) throw new Error(data?.message || "R2 连接失败");
      setNotice({ type: "success", text: data.message || "R2 连接成功" });
    } catch (err: any) {
      setNotice({ type: "error", text: err.message || "R2 连接失败" });
    } finally {
      setTesting(false);
    }
  };

  if (loading) {
    return <div className="flex items-center justify-center rounded-xl border border-adm-border bg-adm-card p-12 text-sm text-adm-text-tertiary">加载中...</div>;
  }

  return (
    <div className="space-y-4">
      <div className="rounded-xl border border-adm-border bg-adm-card p-5">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div className="flex items-start gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-orange-500/10 text-orange-500">
              <Cloud className="h-5 w-5" />
            </div>
            <div>
              <h3 className="text-base font-semibold text-adm-text">Cloudflare R2</h3>
              <p className="mt-1 text-xs leading-5 text-adm-text-secondary">
                使用 S3 兼容 API 保存图片、视频、音频和其他媒体文件。
              </p>
            </div>
          </div>
          <a
            href="https://dash.cloudflare.com/?to=/:account/r2"
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-1 text-xs text-adm-primary hover:underline"
          >
            打开 R2 控制台 <ExternalLink className="h-3 w-3" />
          </a>
        </div>

        <div className="mt-5 flex items-center justify-between rounded-lg bg-adm-input px-3.5 py-3">
          <div>
            <div className="text-sm font-medium text-adm-text">启用 Cloudflare R2</div>
            <div className="mt-0.5 text-xs text-adm-text-tertiary">启用后新上传文件将优先保存到 R2，失败时回退到本地</div>
          </div>
          <button
            type="button"
            role="switch"
            aria-checked={form.enabled}
            onClick={() => update("enabled", !form.enabled)}
            className={`relative h-6 w-11 rounded-full transition-colors ${form.enabled ? "bg-adm-primary" : "bg-adm-text-tertiary/30"}`}
          >
            <span className={`absolute top-1 h-4 w-4 rounded-full bg-white shadow transition-transform ${form.enabled ? "left-6" : "left-1"}`} />
          </button>
        </div>

        <div className="mt-5 grid gap-4 sm:grid-cols-2">
          <Field label="Account ID" value={form.accountId} onChange={(value) => update("accountId", value)} placeholder="Cloudflare 账户 ID" help="R2 Overview 页面中的 Account ID。" />
          <Field label="Bucket 名称" value={form.bucket} onChange={(value) => update("bucket", value)} placeholder="例如 kanle-media" help="需要给 API Token 授予该桶的 Object Read & Write 权限。" />
          <Field label="Access Key ID" value={form.accessKeyId} onChange={(value) => update("accessKeyId", value)} placeholder="R2 API Token 的 Access Key ID" />
          <div>
            <label className="mb-1.5 block text-xs font-medium text-adm-text-secondary">Secret Access Key</label>
            <div className="relative">
              <input
                type={showSecret ? "text" : "password"}
                value={form.secretAccessKey}
                onChange={(event) => update("secretAccessKey", event.target.value)}
                placeholder="R2 API Token 的 Secret Access Key"
                className="w-full rounded-lg border border-adm-border bg-adm-input px-3 py-2.5 pr-10 text-sm text-adm-text outline-none transition-colors focus:border-adm-primary"
              />
              <button type="button" onClick={() => setShowSecret((value) => !value)} className="absolute right-2 top-1/2 -translate-y-1/2 p-1 text-adm-text-tertiary hover:text-adm-text" aria-label={showSecret ? "隐藏密钥" : "显示密钥"}>
                {showSecret ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
              </button>
            </div>
            <p className="mt-1 text-[11px] text-adm-text-tertiary">Secret Access Key 只会在创建 API Token 时显示一次。</p>
          </div>
          <Field label="公开访问域名" value={form.publicDomain} onChange={(value) => update("publicDomain", value)} placeholder="https://pub-xxxx.r2.dev 或 https://img.example.com" help="必须已在 R2 桶设置中启用公开访问或绑定自定义域名。" />
          <Field label="对象路径前缀（可选）" value={form.path} onChange={(value) => update("path", value)} placeholder="例如 uploads" help="文件会按 年/月/随机文件名 保存。" />
        </div>

        <div className="mt-4 rounded-lg border border-adm-border bg-adm-input/50 px-3.5 py-3 text-xs text-adm-text-secondary">
          <div className="font-medium text-adm-text">S3 API Endpoint</div>
          <code className="mt-1 block break-all text-[11px] text-adm-text-tertiary">{endpoint}</code>
        </div>

        <div className="mt-5 flex flex-wrap items-center gap-2">
          <button type="button" onClick={handleSave} disabled={saving} className="inline-flex items-center gap-1.5 rounded-lg bg-adm-primary px-4 py-2.5 text-sm font-medium text-adm-primary-text transition-opacity hover:opacity-90 disabled:opacity-50">
            {saving ? <Loader2 className="h-4 w-4 animate-spin" /> : <Save className="h-4 w-4" />}
            保存配置
          </button>
          <button type="button" onClick={handleTest} disabled={testing || !form.enabled} className="inline-flex items-center gap-1.5 rounded-lg border border-adm-border bg-adm-input px-4 py-2.5 text-sm font-medium text-adm-text-secondary transition-colors hover:bg-adm-card-hover disabled:opacity-50">
            {testing ? <Loader2 className="h-4 w-4 animate-spin" /> : <Cloud className="h-4 w-4" />}
            测试连接
          </button>
        </div>

        {notice && (
          <div className={`mt-4 flex items-start gap-2 rounded-lg border px-3 py-2.5 text-sm ${notice.type === "success" ? "border-green-200 bg-green-50 text-green-700 dark:border-green-900 dark:bg-green-950/30 dark:text-green-400" : "border-red-200 bg-red-50 text-red-700 dark:border-red-900 dark:bg-red-950/30 dark:text-red-400"}`}>
            {notice.type === "success" ? <Check className="mt-0.5 h-4 w-4 shrink-0" /> : <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" />}
            <span>{notice.text}</span>
          </div>
        )}
      </div>

      <div className="rounded-xl border border-adm-border bg-adm-card p-4 text-xs leading-5 text-adm-text-secondary">
        <div className="font-medium text-adm-text">配置提示</div>
        <p className="mt-1">请在 Cloudflare R2 中创建 Bucket 和 API Token，并为 Bucket 开启公开访问地址。应用只使用 S3 API Endpoint 写入和删除对象，浏览器通过公开访问域名读取文件。</p>
      </div>
    </div>
  );
}

function Field({ label, value, onChange, placeholder, help }: { label: string; value: string; onChange: (value: string) => void; placeholder: string; help?: string }) {
  return (
    <div>
      <label className="mb-1.5 block text-xs font-medium text-adm-text-secondary">{label}</label>
      <input value={value} onChange={(event) => onChange(event.target.value)} placeholder={placeholder} className="w-full rounded-lg border border-adm-border bg-adm-input px-3 py-2.5 text-sm text-adm-text outline-none transition-colors focus:border-adm-primary" />
      {help && <p className="mt-1 text-[11px] text-adm-text-tertiary">{help}</p>}
    </div>
  );
}
