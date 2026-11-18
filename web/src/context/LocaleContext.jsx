import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';

const getByPath = (source, dotPath) => {
  if (!source || typeof source !== 'object' || !dotPath) return undefined;
  const parts = dotPath.split('.');
  let cur = source;
  for (const part of parts) {
    if (cur && typeof cur === 'object' && part in cur) {
      cur = cur[part];
    } else {
      return undefined;
    }
  }
  return typeof cur === 'string' && cur.length > 0 ? cur : undefined;
};

const resolveLocale = (locales, key, defaultVal) => {
  if (locales && typeof locales === 'object') {
    const direct = getByPath(locales, key);
    if (direct !== undefined) return direct;

    if (key.startsWith('ui.')) {
      const subKey = key.slice(3);
      const fromUi = getByPath(locales, subKey);
      if (fromUi !== undefined) return fromUi;

      const fromCommon = getByPath(locales.common, subKey);
      if (fromCommon !== undefined) return fromCommon;
    } else if (!key.includes('.')) {
      const fromCommon = getByPath(locales.common, key);
      if (fromCommon !== undefined) return fromCommon;
    }
  }
  return defaultVal ?? key;
};

const formatLocale = (template, params) => {
  if (typeof template !== 'string' || params === undefined || params === null) {
    return template;
  }

  let text = template;
  if (Array.isArray(params)) {
    params.forEach((param) => {
      text = text.replace(/%s|%d|%\.0f|%\.1f/, String(param ?? ''));
    });
  } else if (typeof params === 'object') {
    text = text.replace(/\{([a-zA-Z0-9_]+)\}/g, (match, k) =>
      k in params ? String(params[k]) : match
    );
  } else {
    text = text.replace(/%s|%d|%\.0f|%\.1f/, String(params));
  }
  return text;
};

const LocaleContext = createContext({
  locales: {},
  t: (key, defaultVal, params) => formatLocale(defaultVal ?? key, params),
});

export const LocaleProvider = ({ children }) => {
  const [locales, setLocales] = useState({});

  useEffect(() => {
    if (window.GetParentResourceName) {
      fetch(`https://${window.GetParentResourceName()}/getLocales`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({}),
      })
        .then((res) => res.json())
        .then((data) => {
          if (data && typeof data === 'object') {
            setLocales(data);
          }
        })
        .catch(() => { });
    }
  }, []);

  const t = useCallback(
    (key, defaultVal, params) => {
      const resolved = resolveLocale(locales, key, defaultVal);
      return formatLocale(resolved, params);
    },
    [locales]
  );

  return (
    <LocaleContext.Provider value={{ locales, t }}>
      {children}
    </LocaleContext.Provider>
  );
};

export const useLocale = () => useContext(LocaleContext);

export default LocaleContext;