import React, { useEffect, useState } from 'react';
import { ImageOff } from 'lucide-react';
import { cn } from '../../lib/utils';

interface SmartImageProps extends Omit<React.ImgHTMLAttributes<HTMLImageElement>, 'src'> {
  /** Image URL. When empty/missing — or when the image fails to load — a
   *  neutral "No image" placeholder box is rendered instead of any fallback. */
  src?: string | null;
  /** Optional label shown under the icon in the placeholder. Defaults to "No image". */
  placeholderLabel?: string;
  /** Hide the text label and show only the icon (useful for small avatars). */
  iconOnly?: boolean;
}

/**
 * Drop-in replacement for <img> that shows a "No image" placeholder box when
 * there is no uploaded image (empty src) or the image fails to load.
 *
 * This intentionally has NO fake/fallback imagery — if an admin hasn't uploaded
 * an image, the UI clearly shows that nothing was uploaded.
 *
 * The same `className` is applied to both the <img> and the placeholder <div>,
 * so existing sizing/rounding utilities (e.g. `w-full h-full object-cover`)
 * keep working.
 */
export const SmartImage: React.FC<SmartImageProps> = ({
  src,
  alt = '',
  className,
  placeholderLabel = 'No image',
  iconOnly = false,
  ...rest
}) => {
  const [failed, setFailed] = useState(false);

  // Reset the failed flag whenever the src changes so a new URL gets a fresh try.
  useEffect(() => {
    setFailed(false);
  }, [src]);

  if (!src || failed) {
    return (
      <div
        className={cn(
          'flex flex-col items-center justify-center gap-1 bg-slate-100 text-slate-400 select-none overflow-hidden',
          className
        )}
        role="img"
        aria-label="No image available"
      >
        <ImageOff className="w-6 h-6 shrink-0" strokeWidth={1.5} />
        {!iconOnly && (
          <span className="text-[10px] font-semibold uppercase tracking-wider text-center leading-tight px-1">
            {placeholderLabel}
          </span>
        )}
      </div>
    );
  }

  return (
    <img
      src={src}
      alt={alt}
      className={className}
      onError={() => setFailed(true)}
      {...rest}
    />
  );
};

export default SmartImage;
