/**
 * Design System constants -- ported 1:1 from DesignSystem.swift
 */
export const DS = {
  surface: "#1e1c1a",
  border: "#2a2725",
  muted: "#3d3733",
  dim: "#4a4540",
  subtle: "#6b5b50",
  text: "#b8a99d",
  bright: "#e0d5ca",

  green: "#4a9e69",
  blue: "#5b6d99",
  red: "#c25a4a",
  amber: "#c9a84c",

  greenDim: "rgba(74,158,105,0.08)",
  blueDim: "rgba(91,109,153,0.08)",
  redDim: "rgba(194,90,74,0.08)",
  amberDim: "rgba(201,168,76,0.08)",

  s2: "#242120",
  bg: "#1a1816",
} as const;

/** CSS variable references for inline styles */
export const DSVar = {
  surface: "var(--ds-surface)",
  border: "var(--ds-border)",
  muted: "var(--ds-muted)",
  dim: "var(--ds-dim)",
  subtle: "var(--ds-subtle)",
  text: "var(--ds-text)",
  bright: "var(--ds-bright)",
  green: "var(--ds-green)",
  blue: "var(--ds-blue)",
  red: "var(--ds-red)",
  amber: "var(--ds-amber)",
  greenDim: "var(--ds-green-dim)",
  blueDim: "var(--ds-blue-dim)",
  redDim: "var(--ds-red-dim)",
  amberDim: "var(--ds-amber-dim)",
  s2: "var(--ds-s2)",
  bg: "var(--ds-bg)",
} as const;

export type DSColor = keyof typeof DS;
